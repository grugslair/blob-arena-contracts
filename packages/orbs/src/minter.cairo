use starknet::ContractAddress;

#[derive(Drop, Copy, Serde, Introspect, PartialEq, Default, starknet::Store)]
pub enum Rarity {
    #[default]
    None,
    Common,
    Rare,
    Epic,
    Legendary,
}

#[starknet::interface]
trait IOrbMinter<TState> {
    fn roll(
        ref self: TState, to: ContractAddress, chances_permille: [u32; 4], randomness: u128,
    ) -> u256;
    fn combine_shards(ref self: TState, rarity: Rarity) -> u256;
    fn mint_shards(ref self: TState, to: ContractAddress, rarity: Rarity, amount: u128);
}

#[starknet::interface]
trait IOrbMinterAdmin<TState> {
    fn set_common_orbs(ref self: TState, orbs: Array<felt252>);
    fn set_rare_orbs(ref self: TState, orbs: Array<felt252>);
    fn set_epic_orbs(ref self: TState, orbs: Array<felt252>);
    fn set_legendary_orbs(ref self: TState, orbs: Array<felt252>);
    fn set_shards_in_orbs(ref self: TState, amount: u128);
}

#[derive(Drop, Serde, Introspect)]
struct Shards {
    pub common: u128,
    pub rare: u128,
    pub epic: u128,
    pub legendary: u128,
}

#[starknet::contract]
mod orbs_minter {
    use ba_utils::vrf::{VrfTrait, vrf_component};
    use ba_utils::{SeedProbability, felt252_to_u128};
    use beacon_library::{
        ToriiTable, register_table, register_table_with_schema, set_entity, set_member,
    };
    use core::num::traits::DivRem;
    use sai_access::{AccessTrait, access_component};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address};
    use crate::OrbTrait;
    use super::{IOrbMinter, Rarity, Shards};
    const THOUSAND_NZ: NonZero<u128> = 1000;

    const TABLE_HASH: felt252 = bytearrays_hash!("orbs", "Shards");
    impl ShardsTable = ToriiTable<TABLE_HASH>;

    component!(path: vrf_component, storage: vrf, event: VrfEvents);
    component!(path: access_component, storage: access, event: AccessEvents);


    #[storage]
    struct Storage {
        #[substorage(v0)]
        vrf: vrf_component::Storage,
        #[substorage(v0)]
        access: access_component::Storage,
        orb_contract: ContractAddress,
        common_actions: Map<u32, felt252>,
        rare_actions: Map<u32, felt252>,
        epic_actions: Map<u32, felt252>,
        legendary_actions: Map<u32, felt252>,
        common_actions_amount: u32,
        rare_actions_amount: u32,
        epic_actions_amount: u32,
        legendary_actions_amount: u32,
        common_shards: Map<ContractAddress, u128>,
        rare_shards: Map<ContractAddress, u128>,
        epic_shards: Map<ContractAddress, u128>,
        legendary_shards: Map<ContractAddress, u128>,
        shards_in_orb: u128,
        charge: u128,
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        VrfEvents: vrf_component::Event,
        #[flat]
        AccessEvents: access_component::Event,
    }

    #[constructor]
    fn constructor() {
        register_table_with_schema::<Shards>("orbs", "Shards");
    }


    impl IOrbMinterImpl of IOrbMinter<ContractState> {
        fn roll(
            ref self: ContractState,
            to: ContractAddress,
            chances_permille: [u32; 4],
            mut randomness: u128,
        ) -> u256 {
            self.assert_caller_is_writer();
            let rarity = self.get_random_rarity(chances_permille, ref randomness);
            self.mint_random_action(to, rarity, randomness)
        }

        fn combine_shards(ref self: ContractState, rarity: Rarity) -> u256 {
            let caller = get_caller_address();
            let mut randomness = felt252_to_u128(self.get_nonce_seed(caller));
            let (shard_ptr, selector) = match rarity {
                Rarity::Common => (self.common_shards, selector!("common")),
                Rarity::Rare => (self.rare_shards, selector!("rare")),
                Rarity::Epic => (self.epic_shards, selector!("epic")),
                Rarity::Legendary => (self.legendary_shards, selector!("legendary")),
                Rarity::None => panic!("Invalid rarity for combining shards"),
            };

            let amount_of_shards = shard_ptr.read(caller);
            let shards_in_orb = self.shards_in_orb.read();
            assert(amount_of_shards >= shards_in_orb, 'Not enough shards to combine');
            let new_shards = amount_of_shards - shards_in_orb;
            shard_ptr.write(caller, new_shards);
            ShardsTable::set_member(selector, caller, @new_shards);
            self.mint_random_action(caller, rarity, randomness)
        }

        fn mint_shards(ref self: ContractState, to: ContractAddress, rarity: Rarity, amount: u128) {
            self.assert_caller_is_writer();
            let (shard_ptr, selector) = match rarity {
                Rarity::Common => (self.common_shards, selector!("common")),
                Rarity::Rare => (self.rare_shards, selector!("rare")),
                Rarity::Epic => (self.epic_shards, selector!("epic")),
                Rarity::Legendary => (self.legendary_shards, selector!("legendary")),
                Rarity::None => panic!("Invalid rarity for combining shards"),
            };
            let shards = shard_ptr.read(to) + amount;
            ShardsTable::set_member(selector, to, @shards);
            shard_ptr.write(to, shards);
        }
    }

    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn get_random_rarity(
            self: @ContractState, chances: [u32; 4], ref randomness: u128,
        ) -> Rarity {
            let value = randomness.get_value_nz(THOUSAND_NZ);
            let [common, rare, epic, legendary] = chances;
            let mut chance = common;
            if value < chance.into() {
                return Rarity::Common;
            }
            chance += rare;
            if value < chance.into() {
                return Rarity::Rare;
            }
            chance += epic;
            if value < chance.into() {
                return Rarity::Epic;
            }
            chance += legendary;
            if value < chance.into() {
                return Rarity::Legendary;
            }
            Rarity::None
        }

        fn mint_random_action(
            ref self: ContractState, owner: ContractAddress, rarity: Rarity, randomness: u128,
        ) -> u256 {
            let (amount, actions_ptr) = match rarity {
                Rarity::Common => (self.common_actions_amount.read(), self.common_actions),
                Rarity::Rare => (self.rare_actions_amount.read(), self.rare_actions),
                Rarity::Epic => (self.epic_actions_amount.read(), self.epic_actions),
                Rarity::Legendary => (self.legendary_actions_amount.read(), self.legendary_actions),
                Rarity::None => { return 0; },
            };
            let action = actions_ptr.read(randomness.get_final_value(amount));

            let charge = self.charge.read();
            self.orb_contract.read().mint(owner, action, charge, charge)
        }
    }
}
