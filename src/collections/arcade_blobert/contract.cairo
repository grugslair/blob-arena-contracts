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
///    Models:
///    * BlobertToken
///
/// * `traits` - Retrieves the attributes/traits of a specific Blobert NFT
///    Parameters:
///    * `token_id` - The ID of the token to query
///    Returns:
///    * `TokenAttributes` - The attributes associated with the token
#[starknet::interface]
trait IArcadeBlobert<TContractState> {
    fn mint(ref self: TContractState) -> u256;
    fn burn(ref self: TContractState, token_id: u256);
    fn traits(self: @TContractState, token_id: u256) -> TokenAttributes;
}

const ARCADE_BLOBERT_NAMESPACE_HASH: felt252 = bytearray_hash!("arcade_blobert");

#[dojo::contract]
mod arcade_blobert_actions {
    use core::poseidon::poseidon_hash_span;
    use starknet::{ContractAddress, get_caller_address};
    use dojo::world::WorldStorage;

    use crate::world::{WorldTrait, incrementor};
    use super::super::systems::ArcadeBlobertTrait;
    use super::super::super::blobert::BLOBERT_NAMESPACE_HASH;
    use super::super::super::world_blobert;
    use super::super::super::items::cmp;
    use super::super::super::collection;
    use super::super::super::{IBlobertCollectionImpl, TokenAttributes};

    use super::{IArcadeBlobert, ARCADE_BLOBERT_NAMESPACE_HASH};

    impl ArcadeBlobertStoreImpl =
        world_blobert::WorldBlobertStore<ARCADE_BLOBERT_NAMESPACE_HASH, BLOBERT_NAMESPACE_HASH>;

    #[abi(embed_v0)]
    impl IArcadeBlobertCollectionImpl =
        collection::IBlobertCollectionImpl<ContractState, ArcadeBlobertStoreImpl>;


    #[abi(embed_v0)]
    impl IArcadeBlobertImpl of IArcadeBlobert<ContractState> {
        fn mint(ref self: ContractState) -> u256 {
            let mut storage = self.storage(ARCADE_BLOBERT_NAMESPACE_HASH);
            let randomness = poseidon_hash_span(['arcade', incrementor('SEED-ITER')].span());
            storage.mint_random_blobert(get_caller_address(), randomness)
        }
        fn burn(ref self: ContractState, token_id: u256) {
            let mut storage = self.storage(ARCADE_BLOBERT_NAMESPACE_HASH);
            storage.burn_blobert(token_id);
        }
        fn traits(self: @ContractState, token_id: u256) -> TokenAttributes {
            let dispactcher = self.world_dispatcher();
            dispactcher.attributes(token_id)
        }
    }
}

