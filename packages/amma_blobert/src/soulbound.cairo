use starknet::ContractAddress;

#[starknet::interface]
pub trait IAmmaBlobertSoulboundAdmin<TContractState> {
    fn mint(ref self: TContractState, owner: ContractAddress, fighter: u32);
}

#[starknet::contract]
mod amma_blobert_soulbound {
    use beacon_library::{ToriiTable, register_table_with_schema};
    use core::num::traits::Zero;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc721::interface::IERC721_METADATA_ID;
    use openzeppelin_token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use openzeppelin_upgrades::UpgradeableComponent;
    use sai_access::{AccessTrait, access_component};
    use sai_token::erc721::{ERC721MetadataInfo, soulbound};
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use crate::collectable::{IAmmaBlobert, get_amount_of_fighters};
    use super::IAmmaBlobertSoulboundAdmin;

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: access_component, storage: access, event: AccessEvents);

    const TOKEN_TABLE_ID: felt252 = bytearrays_hash!("amma_blobert", "TokenFighterSoulbound");
    impl TokenTable = ToriiTable<TOKEN_TABLE_ID>;


    #[derive(Drop, Serde, Introspect)]
    struct TokenFighter {
        fighter: u32,
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        access: access_component::Storage,
        collectable_address: ContractAddress,
        token_fighters: Map<u128, u32>,
        tokens_minted: u128,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        AccessEvents: access_component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, owner: ContractAddress, collectable_address: ContractAddress,
    ) {
        self.erc721.initializer_no_metadata();
        self.src5.register_interface(IERC721_METADATA_ID);
        self.grant_owner(owner);
        self.collectable_address.write(collectable_address);
        register_table_with_schema::<TokenFighter>("amma_blobert", "TokenFighterSoulbound");
    }

    #[abi(embed_v0)]
    impl ERC721Impl =
        soulbound::ERC721Soulbound<ContractState, ERC721MetadataInfoImpl>;

    #[abi(embed_v0)]
    impl AccessImpl = access_component::AccessImpl<ContractState>;

    #[abi(embed_v0)]
    impl IAmmaBlobertImpl of IAmmaBlobert<ContractState> {
        fn fighter(self: @ContractState, token_id: u256) -> u32 {
            self.token_fighters.read(token_id.try_into().expect('Invalid token ID'))
        }
        fn number_of_fighters(self: @ContractState) -> u32 {
            get_amount_of_fighters(self.collectable_address.read())
        }
    }

    #[abi(embed_v0)]
    impl IAmmaBlobertSoulboundAdminImpl of IAmmaBlobertSoulboundAdmin<ContractState> {
        fn mint(ref self: ContractState, owner: ContractAddress, fighter: u32) {
            self.assert_caller_is_writer();
            self.mint_internal(owner, fighter);
        }
    }

    // Internal
    impl ERC721MetadataInfoImpl of ERC721MetadataInfo {
        fn name() -> ByteArray {
            // TODO - replace with real name
            "Test AMMA Blobert Soulbound"
        }

        fn symbol() -> ByteArray {
            "TAMMASB"
        }

        fn base_token_uri() -> ByteArray {
            "http://www.example.com/"
        }
    }


    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;


    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn mint_internal(ref self: ContractState, owner: ContractAddress, fighter: u32) -> u256 {
            let token_id = self.tokens_minted.read() + 1;
            self.tokens_minted.write(token_id);
            assert(
                fighter.is_non_zero() && fighter <= self.number_of_fighters(), 'Invalid fighter ID',
            );
            TokenTable::set_entity(token_id, @fighter);
            self.token_fighters.write(token_id, fighter);
            let token_id: u256 = token_id.into();
            self.erc721.mint(owner, token_id);
            token_id
        }
    }
}
