use starknet::ContractAddress;
#[starknet::interface]
pub trait IAmmaBlobert<TContractState> {
    /// Gets the fighter associated with a Blobert token
    /// # Arguments
    /// * `token_id` - The unique identifier of the Blobert token
    /// # Returns
    /// * `u32` - The ID of the fighter associated with the Blobert token
    fn fighter(self: @TContractState, token_id: u256) -> u32;

    /// Gets the total number of fighters
    /// # Returns
    /// * `u32` - The total number of fighters in the contract
    fn number_of_fighters(self: @TContractState) -> u32;
}

#[starknet::interface]
pub trait IAmmaBlobertAdmin<TContractState> {
    fn set_n_fighters(ref self: TContractState, number_of_fighters: u32);
    fn mint(ref self: TContractState, owner: ContractAddress, fighter: u32) -> u256;
}

pub fn get_amount_of_fighters(collection: ContractAddress) -> u32 {
    IAmmaBlobertDispatcher { contract_address: collection }.number_of_fighters()
}

pub fn get_fighter(collection: ContractAddress, token_id: u256) -> u32 {
    IAmmaBlobertDispatcher { contract_address: collection }.fighter(token_id)
}

pub fn mint_fighter(collection: ContractAddress, owner: ContractAddress, fighter: u32) -> u256 {
    IAmmaBlobertAdminDispatcher { contract_address: collection }.mint(owner, fighter)
}

#[derive(Drop, Serde, Introspect)]
pub struct TokenFighter {
    fighter: u32,
}

#[starknet::contract]
mod amma_blobert {
    use beacon_library::{ToriiTable, register_table_with_schema};
    use core::num::traits::Zero;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc721::interface::IERC721_METADATA_ID;
    use openzeppelin_token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use openzeppelin_upgrades::UpgradeableComponent;
    use sai_access::{AccessTrait, access_component};
    use sai_token::erc721::{ERC721MetadataInfo, metadata_impl};
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use super::{IAmmaBlobert, IAmmaBlobertAdmin, TokenFighter};

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: access_component, storage: access, event: AccessEvents);

    const TOKEN_TABLE_ID: felt252 = bytearrays_hash!("amma_blobert", "TokenFighter");
    impl TokenTable = ToriiTable<TOKEN_TABLE_ID>;


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
        number_of_fighters: u32,
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
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.erc721.initializer_no_metadata();
        self.src5.register_interface(IERC721_METADATA_ID);
        self.grant_owner(owner);
        register_table_with_schema::<TokenFighter>("amma_blobert", "TokenFighter");
    }

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;

    #[abi(embed_v0)]
    impl ERC721CamelOnlyImpl = ERC721Component::ERC721CamelOnlyImpl<ContractState>;

    #[abi(embed_v0)]
    impl AccessImpl = access_component::AccessImpl<ContractState>;

    #[abi(embed_v0)]
    impl ERC721Metadata =
        metadata_impl::IERC721MetadataImpl<ContractState, ERC721MetadataInfoImpl>;

    #[abi(embed_v0)]
    impl IAmmaBlobertImpl of IAmmaBlobert<ContractState> {
        fn fighter(self: @ContractState, token_id: u256) -> u32 {
            self.token_fighters.read(token_id.try_into().expect('Invalid token ID'))
        }
        fn number_of_fighters(self: @ContractState) -> u32 {
            self.number_of_fighters.read()
        }
    }

    #[abi(embed_v0)]
    impl IAmmaBlobertAdminImpl of IAmmaBlobertAdmin<ContractState> {
        fn set_n_fighters(ref self: ContractState, number_of_fighters: u32) {
            self.assert_caller_is_owner();
            assert(number_of_fighters >= self.number_of_fighters.read(), 'Cannot reduce fighters');
            self.number_of_fighters.write(number_of_fighters);
        }

        fn mint(ref self: ContractState, owner: ContractAddress, fighter: u32) -> u256 {
            self.assert_caller_is_writer();
            self.mint_internal(owner, fighter)
        }
    }

    // Internal
    impl ERC721MetadataInfoImpl of ERC721MetadataInfo {
        fn name() -> ByteArray {
            // TODO - replace with real name
            "Test AMMA Blobert"
        }

        fn symbol() -> ByteArray {
            "TESTAMMA"
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
                fighter.is_non_zero() && fighter <= self.number_of_fighters.read(),
                'Invalid fighter ID',
            );
            TokenTable::set_entity(token_id, @fighter);
            self.token_fighters.write(token_id, fighter);
            let token_id: u256 = token_id.into();
            self.erc721.mint(owner, token_id);
            token_id
        }
    }
}
