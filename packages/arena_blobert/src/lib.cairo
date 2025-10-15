mod minter;
use ba_blobert::TokenTraits;
use starknet::ContractAddress;

/// Main interface for Arena Blobert NFT holders
///
/// Provides core functionality for NFT owners to interact with their Arena Blobert tokens.
/// These are soulbound NFTs used in the Blob Arena game system.
#[starknet::interface]
pub trait IArenaBlobert<TContractState> {
    /// Burns an Arena Blobert NFT permanently
    ///
    /// Destroys the specified NFT, removing it from circulation permanently.
    /// Only the token owner or someone approved can burn an NFT.
    ///
    /// # Arguments
    /// * `token_id` - The unique identifier of the NFT to burn
    fn burn(ref self: TContractState, token_id: u256);

    /// Retrieves the traits configuration for a specific Arena Blobert
    ///
    /// Returns the complete trait information that defines the NFT's characteristics,
    /// including visual appearance and game mechanics properties.
    ///
    /// # Arguments
    /// * `token_id` - The unique identifier of the NFT to query
    ///
    /// # Returns
    /// * `TokenTraits` - Complete trait configuration (Seed or Custom variant)
    fn traits(self: @TContractState, token_id: u256) -> TokenTraits;
}

#[starknet::interface]
trait IArenaBlobertAdmin<TContractState> {
    /// Mints a new Arena Blobert NFT with specified traits
    ///
    /// Creates a new Arena Blobert NFT and assigns it to the specified owner.
    /// The traits determine the NFT's visual appearance and game mechanics.
    ///
    /// # Arguments
    /// * `owner` - The address that will receive the newly minted NFT
    /// * `traits` - The trait configuration for the new NFT (Seed or Custom)
    ///
    /// # Returns
    /// * `u256` - The token ID of the newly minted NFT
    fn mint(ref self: TContractState, owner: ContractAddress, traits: TokenTraits) -> u256;

    /// Gets the total number of Arena Blobert NFTs that have been minted
    ///
    /// Returns the cumulative count of all NFTs created since contract deployment.
    /// This count includes burned NFTs and represents total lifetime minting.
    ///
    /// # Returns
    /// * `u256` - Total number of NFTs minted (including burned ones)
    fn total_minted(self: @TContractState) -> u256;
}

#[starknet::contract]
mod arena_blobert {
    use ba_blobert::{Seed, TokenTraits};
    use beacon_library::{ToriiTable, register_table_with_schema};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc721::interface::IERC721_METADATA_ID;
    use openzeppelin_token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
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
    component!(path: access_component, storage: access, event: AccessEvents);

    const TOKEN_TABLE_ID: felt252 = bytearrays_hash!("arena_blobert", "Traits");
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
        traits: TokenTraits,
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
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
        AccessEvents: access_component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.erc721.initializer_no_metadata();
        self.src5.register_interface(IERC721_METADATA_ID);
        self.grant_owner(owner);
        register_table_with_schema::<ArenaBlobertToken>("arena_blobert", "Traits");
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

        fn traits(self: @ContractState, token_id: u256) -> TokenTraits {
            let token_id: u128 = token_id.try_into().expect('Invalid token ID');
            let token_type = self.token_types.read(token_id);
            match token_type {
                TokenType::Seed => { TokenTraits::Seed(self.token_seeds.read(token_id)) },
                TokenType::Custom => { TokenTraits::Custom(self.token_customs.read(token_id)) },
                _ => panic!("Token not minted"),
            }
        }
    }

    #[abi(embed_v0)]
    impl IArenaBlobertAdminImpl of IArenaBlobertAdmin<ContractState> {
        fn mint(ref self: ContractState, owner: ContractAddress, traits: TokenTraits) -> u256 {
            self.assert_caller_is_writer();
            self.mint_internal(owner, traits)
        }

        fn total_minted(self: @ContractState) -> u256 {
            self.tokens_minted.read().into()
        }
    }


    // Internal
    impl ERC721MetadataInfoImpl of ERC721MetadataInfo {
        fn name() -> ByteArray {
            //TODO - replace with real name
            "TEST Arena Blobert"
        }

        fn symbol() -> ByteArray {
            "TESTBABLOB"
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
            ref self: ContractState, owner: ContractAddress, traits: TokenTraits,
        ) -> u256 {
            let minted = self.tokens_minted.read() + 1;
            self.tokens_minted.write(minted);
            let token_id = minted + 4844;
            match traits {
                TokenTraits::Seed(seed) => {
                    self.token_seeds.write(token_id, seed);
                    self.token_types.write(token_id, TokenType::Seed);
                },
                TokenTraits::Custom(custom) => {
                    self.token_customs.write(token_id, custom);
                    self.token_types.write(token_id, TokenType::Custom);
                },
            }
            TokenTable::set_entity(token_id, @traits);
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

