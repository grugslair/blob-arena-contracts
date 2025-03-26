use starknet::ContractAddress;
use super::TokenAttributes;

/// Contract interface for AMMA Blobert NFT collection
///
/// # Interface Functions
///
/// * `mint` - Mints a new Blobert NFT based on a fighter type
///   * `fighter` - The id of the amma fighter to mint
///   * Returns the minted token ID
/// Models:
/// - BlobertToken
///
///
/// * `traits` - Gets the attributes/traits for a specific token
///   * `token_id` - ID of the token to query
///   * Returns TokenAttributes struct containing the token's traits

#[starknet::interface]
trait IAmmaBlobert<TContractState> {
    fn mint(ref self: TContractState, fighter: felt252) -> felt252;
    fn traits(self: @TContractState, token_id: u256) -> TokenAttributes;
}

#[dojo::contract]
mod amma_blobert_actions {
    use core::poseidon::poseidon_hash_span;
    use starknet::{ContractAddress, get_caller_address};
    use dojo::world::{WorldStorage, IWorldDispatcher};

    use crate::world::WorldTrait;
    use super::super::world_blobert::{WorldBlobertStore, WorldBlobertStorage};
    use super::super::items::cmp;
    use super::super::collection;
    // use super::super::items::IBlobertItemsImpl;
    use super::super::{IBlobertCollectionImpl, TokenAttributes};
    use super::IAmmaBlobert;
    const AMMA_BLOBERT_NAMESPACE_HASH: felt252 = bytearray_hash!("amma_blobert");


    impl ArcadeBlobertStoreImpl =
        WorldBlobertStore<AMMA_BLOBERT_NAMESPACE_HASH, AMMA_BLOBERT_NAMESPACE_HASH>;

    #[abi(embed_v0)]
    impl IAmmaBlobertItems =
        cmp::IBlobertItemsImpl<ContractState, ArcadeBlobertStoreImpl>;

    #[abi(embed_v0)]
    impl IAmmaBlobertCollectionImpl =
        collection::IBlobertCollectionImpl<ContractState, ArcadeBlobertStoreImpl>;

    #[abi(embed_v0)]
    impl IAmmaBlobertImpl of IAmmaBlobert<ContractState> {
        fn mint(ref self: ContractState, fighter: felt252) -> felt252 {
            let mut storage = self.storage(AMMA_BLOBERT_NAMESPACE_HASH);
            let owner = get_caller_address();
            let id = poseidon_hash_span([owner.into(), fighter].span());
            storage.set_blobert_token(id.into(), owner, TokenAttributes::Custom(fighter));
            id
        }
        fn traits(self: @ContractState, token_id: u256) -> TokenAttributes {
            let storage = self.storage(AMMA_BLOBERT_NAMESPACE_HASH);
            storage.get_blobert_token_attributes(token_id)
        }
    }
}

