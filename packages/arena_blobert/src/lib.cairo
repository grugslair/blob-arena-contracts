use ba_blobert::TokenAttributes;
use starknet::ContractAddress;

#[starknet::interface]
pub trait IArenaBlobert<TContractState> {
    fn burn(ref self: TContractState, token_id: u256);
    fn traits(self: @TContractState, token_id: u256) -> TokenAttributes;
}

#[starknet::interface]
trait IArenaBlobertAdmin<TContractState> {
    fn mint(ref self: TContractState, owner: ContractAddress, attributes: TokenAttributes) -> u256;
}

#[starknet::contract]
mod arena_blobert {
    use ba_blobert::{Seed, TokenAttributes};
    use beacon_library::{ToriiTable, register_table_with_schema};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc721::interface::IERC721_METADATA_ID;
    use openzeppelin_token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use openzeppelin_upgrades::UpgradeableComponent;
    use sai_access::{AccessTrait, access_component};
    use sai_token::erc721::{ERC721MetadataInfo, soulbound};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address};
    use super::{IArenaBlobert, IArenaBlobertAdmin};

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: access_component, storage: access, event: AccessEvents);

    const TOKEN_TABLE_ID: felt252 = bytearrays_hash!("arena_blobert", "TokenAttributes");
    impl TokenTable = ToriiTable<TOKEN_TABLE_ID>;

    #[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
    enum TokenType {
        #[default]
        NotMinted,
        Seed,
        Custom,
    }

    #[derive(Drop, Serde, Introspect)]
    struct ArenaBlobertToken {
        attributes: TokenAttributes,
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
        tokens_minted: u128,
        token_seeds: Map<u128, Seed>,
        token_customs: Map<u128, u32>,
        token_types: Map<u128, TokenType>,
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
        register_table_with_schema::<ArenaBlobertToken>("arena_blobert", "TokenAttributes");
    }

    #[abi(embed_v0)]
    impl ERC721Impl =
        soulbound::ERC721Soulbound<ContractState, ERC721MetadataInfoImpl>;

    #[abi(embed_v0)]
    impl AccessImpl = access_component::AccessImpl<ContractState>;

    #[abi(embed_v0)]
    impl IArenaBlobertImpl of IArenaBlobert<ContractState> {
        fn burn(ref self: ContractState, token_id: u256) {
            self.caller_is_token_owner(token_id);
            self.erc721.burn(token_id);
            self
                .token_types
                .write(token_id.try_into().expect('Invalid token ID'), TokenType::NotMinted);
        }

        fn traits(self: @ContractState, token_id: u256) -> TokenAttributes {
            let token_id: u128 = token_id.try_into().expect('Invalid token ID');
            let token_type = self.token_types.read(token_id);
            match token_type {
                TokenType::Seed => { TokenAttributes::Seed(self.token_seeds.read(token_id)) },
                TokenType::Custom => { TokenAttributes::Custom(self.token_customs.read(token_id)) },
                _ => panic!("Token not minted"),
            }
        }
    }

    #[abi(embed_v0)]
    impl IArenaBlobertAdminImpl of IArenaBlobertAdmin<ContractState> {
        fn mint(
            ref self: ContractState, owner: ContractAddress, attributes: TokenAttributes,
        ) -> u256 {
            self.assert_caller_is_writer();
            self.mint_internal(owner, attributes)
        }
    }


    // Internal
    impl ERC721MetadataInfoImpl of ERC721MetadataInfo {
        fn name() -> ByteArray {
            "Arena Blobert"
        }

        fn symbol() -> ByteArray {
            "BABLOB"
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
        fn mint_internal(
            ref self: ContractState, owner: ContractAddress, attributes: TokenAttributes,
        ) -> u256 {
            let minted = self.tokens_minted.read() + 1;
            self.tokens_minted.write(minted);
            let token_id = minted + 4844;
            match attributes {
                TokenAttributes::Seed(seed) => {
                    self.token_seeds.write(token_id, seed);
                    self.token_types.write(token_id, TokenType::Seed);
                },
                TokenAttributes::Custom(custom) => {
                    self.token_customs.write(token_id, custom);
                    self.token_types.write(token_id, TokenType::Custom);
                },
            }
            TokenTable::set_entity(token_id, @attributes);
            let token_id: u256 = token_id.into();
            self.erc721.mint(owner, token_id);
            token_id
        }

        fn caller_is_token_owner(self: @ContractState, token_id: u256) {
            assert(
                get_caller_address() == self.erc721._owner_of(token_id),
                'Caller is not the token owner',
            );
        }
    }
}

