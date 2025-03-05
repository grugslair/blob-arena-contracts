use starknet::ContractAddress;
use blob_arena::collections::blobert::external::TokenAttributes;

/// Interface for the ArcadeBlobert NFT contract
///
/// # Interface Functions
///
/// * `mint` - Mints a random Blobert NFT and returns its token ID
///    Returns:
///    * `u256` - The ID of the newly minted token
///
/// * `traits` - Retrieves the attributes/traits of a specific Blobert NFT
///    Parameters:
///    * `token_id` - The ID of the token to query
///    Returns:
///    * `TokenAttributes` - The attributes associated with the token
#[starknet::interface]
trait IArcadeBlobert<TContractState> {
    fn mint(ref self: TContractState) -> u256;
    fn traits(self: @TContractState, token_id: u256) -> TokenAttributes;
}

#[dojo::contract]
mod arcade_blobert_actions {
    use starknet::{ContractAddress, get_caller_address};
    use dojo::world::WorldStorage;
    use blob_arena::{
        collections::{ICollection, blobert, arcade_blobert}, stats::UStats, default_namespace,
    };
    use blobert::{blobert_namespace, BlobertTrait, BlobertStorage, TokenAttributes};
    use arcade_blobert::{
        ArcadeBlobertStorage, mint::ArcadeBlobertMintTrait, collection::BlobertCollectionTrait,
    };
    use super::IArcadeBlobert;

    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn storage(self: @ContractState) -> WorldStorage {
            self.world(@"arcade_blobert")
        }
    }

    impl ArcadeBlobertCollectionImpl of BlobertCollectionTrait<ContractState> {
        fn blobert_storage(self: @ContractState) -> WorldStorage {
            self.world(blobert_namespace())
        }
        fn attributes(self: @ContractState, token_id: u256) -> TokenAttributes {
            self.storage().get_blobert_token_attributes(token_id)
        }
        fn owner(self: @ContractState, token_id: u256) -> ContractAddress {
            self.storage().get_blobert_token_owner(token_id)
        }
    }

    #[abi(embed_v0)]
    impl IArcadeBlobertCollectionImpl =
        arcade_blobert::collection::IBlobertCollectionImpl<ContractState>;


    #[abi(embed_v0)]
    impl IArcadeBlobertImpl of IArcadeBlobert<ContractState> {
        fn mint(ref self: ContractState) -> u256 {
            let mut storage = self.storage();
            storage.mint_random_blobert(get_caller_address())
        }
        fn traits(self: @ContractState, token_id: u256) -> TokenAttributes {
            self.attributes(token_id)
        }
    }
}

