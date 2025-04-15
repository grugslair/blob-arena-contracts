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
trait ITestBlobert<TContractState> {
    fn mint(ref self: TContractState, fighter: felt252) -> u256;
    fn traits(self: @TContractState, token_id: u256) -> TokenAttributes;
}

#[dojo::contract]
mod test_blobert_actions {
    use core::poseidon::poseidon_hash_span;
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use dojo::world::{WorldStorage, IWorldDispatcher};
    use crate::world::WorldTrait;
    use crate::starknet::return_value;
    use crate::permissions::{Role, Permissions};
    use super::super::world_blobert::{WorldBlobertStore, WorldBlobertStorage};
    use super::super::items::cmp;
    use super::super::collection;
    use super::super::{
        IBlobertCollectionImpl, TokenAttributes, CollectionGroupStorage, CollectionGroup,
    };
    use super::ITestBlobert;
    const TEST_BLOBERT_NAMESPACE_HASH: felt252 = bytearray_hash!("testing");

    fn dojo_init(ref self: ContractState) {
        let mut storage = self.default_storage();
        storage.set_collection_group(get_contract_address(), CollectionGroup::TestBlobert);
    }


    impl TestBlobertStoreImpl =
        WorldBlobertStore<TEST_BLOBERT_NAMESPACE_HASH, TEST_BLOBERT_NAMESPACE_HASH>;

    #[abi(embed_v0)]
    impl ITestBlobertItems =
        cmp::IBlobertItemsImpl<ContractState, Role::Tester, TestBlobertStoreImpl>;

    #[abi(embed_v0)]
    impl ITestBlobertCollectionImpl =
        collection::IBlobertCollectionImpl<ContractState, TestBlobertStoreImpl>;

    #[abi(embed_v0)]
    impl ITestBlobertImpl of ITestBlobert<ContractState> {
        fn mint(ref self: ContractState, fighter: felt252) -> u256 {
            let mut storage = self.storage(TEST_BLOBERT_NAMESPACE_HASH);
            let owner = get_caller_address();
            storage.assert_has_permission(owner, Role::Tester);
            let id = poseidon_hash_span([owner.into(), fighter].span());
            storage.set_blobert_token(id.into(), owner, TokenAttributes::Custom(fighter));
            return_value(id.into())
        }
        fn traits(self: @ContractState, token_id: u256) -> TokenAttributes {
            let storage = self.storage(TEST_BLOBERT_NAMESPACE_HASH);
            storage.get_blobert_token_attributes(token_id)
        }
    }
}

