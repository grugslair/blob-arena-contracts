use core::num::traits::Zero;
use starknet::ContractAddress;

#[derive(Drop, Copy, Serde, Introspect, PartialEq, Default, starknet::Store)]
enum Rarity {
    #[default]
    None,
    Common,
    Rare,
    Epic,
    Legendary,
    Chaotic,
}


#[derive(Drop, Copy, Serde, Introspect, PartialEq)]
enum Role {
    Owner,
    Minter,
    Charger,
    Consumer,
}

#[starknet::interface]
pub trait IOrb<TContractState> {
    fn attack(self: @TContractState, token_id: u256) -> felt252;
    fn charge(self: @TContractState, token_id: u256) -> u128;
    fn rarity(self: @TContractState, token_id: u256) -> Rarity;
    fn charge_cost(self: @TContractState, token_id: u256) -> u128;
}

#[starknet::interface]
pub trait IOrbAdmin<TContractState> {
    fn mint(
        ref self: TContractState,
        owner: ContractAddress,
        attack: felt252,
        charge: u128,
        charge_cost: u128,
        rarity: Rarity,
    ) -> u256;
    fn add_charge_cost(ref self: TContractState, token_id: u256);
    fn add_charge_amount(ref self: TContractState, token_id: u256, amount: u128);
    fn try_use_charge_cost(ref self: TContractState, token_id: u256) -> bool;
    fn try_use_charge_amount(ref self: TContractState, token_id: u256, amount: u128) -> bool;
    fn grant_role(ref self: TContractState, user: ContractAddress, role: Role);
    fn revoke_role(ref self: TContractState, user: ContractAddress, role: Role);
    fn has_role(self: @TContractState, user: ContractAddress, role: Role) -> bool;
}


#[derive(Drop, Serde, Introspect)]
pub struct Orb {
    attack: felt252,
    charge: u128,
    rarity: Rarity,
    charge_cost: u128,
}

pub fn downcast_id(id: u256) -> felt252 {
    assert(id.is_non_zero(), 'ID cannot be zero');
    id.try_into().expect('Invalid token ID')
}

#[starknet::contract]
mod orbs {
    use beacon_library::{ToriiTable, register_table_with_schema};
    use core::num::traits::Zero;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc721::interface::IERC721_METADATA_ID;
    use openzeppelin_token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use sai_token::erc721::{ERC721MetadataInfo, metadata_impl};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address};
    use crate::Role;
    use super::{IOrb, IOrbAdmin, Orb, Rarity, downcast_id};

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    const ORB_TABLE_ID: felt252 = bytearrays_hash!("ba_orbs", "Orbs");
    impl OrbTable = ToriiTable<ORB_TABLE_ID>;

    #[derive(Drop, Serde, starknet::Event)]
    struct GrantRole {
        #[key]
        role: Role,
        #[key]
        user: ContractAddress,
    }
    #[derive(Drop, Serde, starknet::Event)]
    struct RevokeRole {
        #[key]
        role: Role,
        #[key]
        user: ContractAddress,
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        charges: Map<felt252, u128>,
        attacks: Map<felt252, felt252>,
        rarities: Map<felt252, Rarity>,
        charge_costs: Map<felt252, u128>,
        tokens_minted: felt252,
        role_owners: Map<ContractAddress, bool>,
        role_minters: Map<ContractAddress, bool>,
        role_chargers: Map<ContractAddress, bool>,
        role_consumers: Map<ContractAddress, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        GrantRole: GrantRole,
        RevokeRole: RevokeRole,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.erc721.initializer_no_metadata();
        self.src5.register_interface(IERC721_METADATA_ID);
        self.grant_role_internal(owner, Role::Owner);
        register_table_with_schema::<Orb>("ba_orbs", "Orbs");
    }

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;

    #[abi(embed_v0)]
    impl ERC721CamelOnlyImpl = ERC721Component::ERC721CamelOnlyImpl<ContractState>;

    #[abi(embed_v0)]
    impl ERC721Metadata =
        metadata_impl::IERC721MetadataImpl<ContractState, ERC721MetadataInfoImpl>;

    #[abi(embed_v0)]
    impl IOrbImpl of IOrb<ContractState> {
        fn attack(self: @ContractState, token_id: u256) -> felt252 {
            self.attacks.read(downcast_id(token_id))
        }

        fn charge(self: @ContractState, token_id: u256) -> u128 {
            self.charges.read(downcast_id(token_id))
        }

        fn rarity(self: @ContractState, token_id: u256) -> Rarity {
            self.rarities.read(downcast_id(token_id))
        }

        fn charge_cost(self: @ContractState, token_id: u256) -> u128 {
            self.charge_costs.read(downcast_id(token_id))
        }
    }

    #[abi(embed_v0)]
    impl IOrbAdminImpl of IOrbAdmin<ContractState> {
        fn mint(
            ref self: ContractState,
            owner: ContractAddress,
            attack: felt252,
            charge: u128,
            charge_cost: u128,
            rarity: Rarity,
        ) -> u256 {
            self.assert_caller_has_role(Role::Minter);
            self.mint_internal(owner, attack, charge, charge_cost, rarity)
        }

        fn add_charge_cost(ref self: ContractState, token_id: u256) {
            self.assert_caller_has_role(Role::Charger);
            let token_id = downcast_id(token_id);
            self.increase_token_charge(token_id, self.charge_costs.read(token_id))
        }

        fn add_charge_amount(ref self: ContractState, token_id: u256, amount: u128) {
            self.assert_caller_has_role(Role::Charger);
            self.increase_token_charge(downcast_id(token_id), amount);
        }

        fn try_use_charge_cost(ref self: ContractState, token_id: u256) -> bool {
            self.assert_caller_has_role(Role::Consumer);
            let token_id = downcast_id(token_id);
            self.decrease_token_charge(token_id, self.charge_costs.read(token_id))
        }

        fn try_use_charge_amount(ref self: ContractState, token_id: u256, amount: u128) -> bool {
            self.assert_caller_has_role(Role::Consumer);
            let token_id = downcast_id(token_id);
            self.decrease_token_charge(token_id, amount)
        }

        fn grant_role(ref self: ContractState, user: ContractAddress, role: Role) {
            self.assert_caller_has_role(Role::Owner);
            self.grant_role_internal(user, role);
        }

        fn revoke_role(ref self: ContractState, user: ContractAddress, role: Role) {
            self.assert_caller_has_role(Role::Owner);
            self.revoke_role_internal(user, role);
        }

        fn has_role(self: @ContractState, user: ContractAddress, role: Role) -> bool {
            self.has_role_inner(user, role)
        }
    }

    // Internal
    impl ERC721MetadataInfoImpl of ERC721MetadataInfo {
        fn name() -> ByteArray {
            // TODO - replace with real name
            "Test BA Orbs"
        }

        fn symbol() -> ByteArray {
            "TESTBAORBS"
        }

        fn base_token_uri() -> ByteArray {
            "http://www.example.com/"
        }
    }


    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;


    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn mint_internal(
            ref self: ContractState,
            owner: ContractAddress,
            attack: felt252,
            charge: u128,
            charge_cost: u128,
            rarity: Rarity,
        ) -> u256 {
            let token_id = self.tokens_minted.read() + 1;
            self.tokens_minted.write(token_id);
            assert(attack.is_non_zero(), 'Invalid attack ID');
            assert(charge_cost.is_non_zero(), 'Charge cost cannot be zero');
            OrbTable::set_entity(token_id, @Orb { attack, charge, rarity, charge_cost });
            self.attacks.write(token_id, attack);
            self.charges.write(token_id, charge);
            self.rarities.write(token_id, rarity);
            self.charge_costs.write(token_id, charge_cost);
            let token_id: u256 = token_id.into();
            self.erc721.mint(owner, token_id);
            token_id
        }

        fn assert_caller_has_role(ref self: ContractState, role: Role) {
            let caller = get_caller_address();
            match role {
                Role::Owner => assert(self.role_owners.read(caller), 'Caller is not the owner'),
                Role::Minter => assert(self.role_minters.read(caller), 'Caller is not a minter'),
                Role::Charger => assert(self.role_chargers.read(caller), 'Caller is not a charger'),
                Role::Consumer => assert(
                    self.role_consumers.read(caller), 'Caller is not a consumer',
                ),
            }
        }

        fn has_role_inner(self: @ContractState, user: ContractAddress, role: Role) -> bool {
            match role {
                Role::Owner => self.role_owners.read(user),
                Role::Minter => self.role_minters.read(user),
                Role::Charger => self.role_chargers.read(user),
                Role::Consumer => self.role_consumers.read(user),
            }
        }

        fn grant_role_internal(ref self: ContractState, user: ContractAddress, role: Role) {
            match role {
                Role::Owner => self.role_owners.write(user, true),
                Role::Minter => self.role_minters.write(user, true),
                Role::Charger => self.role_chargers.write(user, true),
                Role::Consumer => self.role_consumers.write(user, true),
            }
            self.emit(GrantRole { role, user });
        }

        fn revoke_role_internal(ref self: ContractState, user: ContractAddress, role: Role) {
            match role {
                Role::Owner => self.role_owners.write(user, false),
                Role::Minter => self.role_minters.write(user, false),
                Role::Charger => self.role_chargers.write(user, false),
                Role::Consumer => self.role_consumers.write(user, false),
            }
            self.emit(RevokeRole { role, user });
        }
        fn increase_token_charge(ref self: ContractState, token_id: felt252, amount: u128) {
            let token_charge = self.charges.entry(token_id);
            let new_charge = token_charge.read() + amount;
            token_charge.write(new_charge);
            OrbTable::set_member(selector!("charge"), token_id, @new_charge);
        }

        fn decrease_token_charge(ref self: ContractState, token_id: felt252, amount: u128) -> bool {
            let token_charge = self.charges.entry(token_id);
            let current_charge = token_charge.read();
            if current_charge < amount {
                false
            } else {
                let new_charge = token_charge.read() - amount;
                token_charge.write(new_charge);
                OrbTable::set_member(selector!("charge"), token_id, @new_charge);
                true
            }
        }
    }
}
