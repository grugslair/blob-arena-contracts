use starknet::ContractAddress;
use blob_arena::collections::blobert::TokenAttributes;

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
trait IAMMABlobert<TContractState> {
    fn mint(ref self: TContractState, fighter: felt252) -> felt252;
    fn traits(self: @TContractState, token_id: u256) -> TokenAttributes;
}

#[dojo::contract]
mod amma_blobert_actions {
    use core::poseidon::poseidon_hash_span;
    use starknet::{ContractAddress, get_caller_address};
    use dojo::world::WorldStorage;
    use blob_arena::{
        DefaultStorage, attacks::components::AttackInput, stats::UStats, default_namespace,
    };
    use blob_arena::collections::{blobert, free_blobert, interface::ICollection};
    use free_blobert::{FreeBlobertStorage, BlobertCollectionTrait};
    use blobert::{
        blobert_namespace, BlobertTrait, BlobertStorage, TokenAttributes, BlobertItemKey,
        to_seed_key, BlobertAttribute,
    };
    use super::IAMMABlobert;
    const AMMA_BLOBERT_NAMESPACE_HASH: felt252 = bytearray_hash!("amma_blobert");

    impl DefaultStorageImpl of DefaultStorage<ContractState> {
        fn default_storage(self: @ContractState) -> WorldStorage {
            self.world_ns_hash(AMMA_BLOBERT_NAMESPACE_HASH)
        }
    }

    mod permissioned_storage {
        use super::{DefaultStorage, ContractState, WorldStorage};
        use blob_arena::{permissions::{Permissions, Role}, world::get_default_storage};
        impl DefaultStorageImpl of DefaultStorage<ContractState> {
            fn default_storage(self: @ContractState) -> WorldStorage {
                get_default_storage().assert_caller_has_permission(Role::AmmaAdmin);
                super::DefaultStorageImpl::default_storage(self)
            }
        }
    }

    impl FreeBlobertCollectionImpl of BlobertCollectionTrait<ContractState> {
        fn blobert_storage(self: @ContractState) -> WorldStorage {
            self.default_storage()
        }
        fn attributes(self: @ContractState, token_id: u256) -> TokenAttributes {
            self.default_storage().get_blobert_token_attributes(token_id)
        }
        fn owner(self: @ContractState, token_id: u256) -> ContractAddress {
            self.default_storage().get_blobert_token_owner(token_id)
        }
    }

    #[abi(embed_v0)]
    impl IAMMABlobertItems =
        blobert::items::IBlobertItemsImpl<ContractState, permissioned_storage::DefaultStorageImpl>;

    #[abi(embed_v0)]
    impl IFreeBlobertCollectionImpl =
        free_blobert::collection::IBlobertCollectionImpl<ContractState>;

    #[abi(embed_v0)]
    impl IAMMABlobertImpl of IAMMABlobert<ContractState> {
        fn mint(ref self: ContractState, fighter: felt252) -> felt252 {
            let mut storage = self.default_storage();
            let owner = get_caller_address();
            let id = poseidon_hash_span([owner.into(), fighter].span());
            storage.set_blobert_token(id, owner, TokenAttributes::Custom(fighter));
            id
        }
        fn traits(self: @ContractState, token_id: u256) -> TokenAttributes {
            let storage = self.default_storage();
            storage.get_blobert_token_attributes(token_id)
        }
    }
}

