use starknet::ContractAddress;
use blob_arena::collections::blobert::external::TokenAttributes;

/// Interface for the FreeBlobert NFT contract
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
trait IFreeBlobert<TContractState> {
    fn mint(ref self: TContractState) -> u256;
    fn burn(ref self: TContractState, token_id: u256);
    fn traits(self: @TContractState, token_id: u256) -> TokenAttributes;
}

#[starknet::interface]
trait IFreeBlobertAdmin<TContractState> {
    fn admin_mint(
        ref self: TContractState, player: ContractAddress, attributes: TokenAttributes,
    ) -> u256;
    fn admin_mint_seed(
        ref self: TContractState,
        player: ContractAddress,
        background: u32,
        armour: u32,
        jewelry: u32,
        mask: u32,
        weapon: u32,
    ) -> u256;
}

const FREE_BLOBERT_NAMESPACE_HASH: felt252 = bytearray_hash!("free_blobert");

#[dojo::contract]
mod free_blobert_actions {
    use core::poseidon::poseidon_hash_span;
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use dojo::world::WorldStorage;

    use crate::world::{WorldTrait, incrementor, uuid};
    use crate::starknet::return_value;
    use crate::permissions::{Role, Permissions};
    use super::super::systems::FreeBlobertTrait;
    use super::super::super::blobert::BLOBERT_NAMESPACE_HASH;
    use super::super::super::world_blobert;
    use super::super::super::collection;
    use super::super::super::world_blobert::WorldBlobertStorage;
    use super::super::super::{
        IBlobertCollectionImpl, TokenAttributes, CollectionGroupStorage, CollectionGroup, Seed,
    };
    use super::{IFreeBlobert, FREE_BLOBERT_NAMESPACE_HASH, IFreeBlobertAdmin};

    fn dojo_init(ref self: ContractState) {
        let mut storage = self.default_storage();
        storage.set_collection_group(get_contract_address(), CollectionGroup::FreeBlobert);
    }

    impl FreeBlobertStoreImpl =
        world_blobert::WorldBlobertStore<FREE_BLOBERT_NAMESPACE_HASH, BLOBERT_NAMESPACE_HASH>;

    #[abi(embed_v0)]
    impl IFreeBlobertCollectionImpl =
        collection::IBlobertCollectionImpl<ContractState, FreeBlobertStoreImpl>;


    #[abi(embed_v0)]
    impl IFreeBlobertImpl of IFreeBlobert<ContractState> {
        fn mint(ref self: ContractState) -> u256 {
            let mut storage = self.storage(FREE_BLOBERT_NAMESPACE_HASH);
            let randomness = poseidon_hash_span(['free', incrementor('SEED-ITER')].span());
            return_value(storage.mint_random_blobert(get_caller_address(), randomness))
        }
        fn burn(ref self: ContractState, token_id: u256) {
            let mut storage = self.storage(FREE_BLOBERT_NAMESPACE_HASH);
            storage.burn_blobert(token_id);
        }
        fn traits(self: @ContractState, token_id: u256) -> TokenAttributes {
            let dispactcher = self.world_dispatcher();
            dispactcher.attributes(token_id)
        }
    }

    #[abi(embed_v0)]
    impl IFreeBlobertAdminImpl of IFreeBlobertAdmin<ContractState> {
        fn admin_mint(
            ref self: ContractState, player: ContractAddress, attributes: TokenAttributes,
        ) -> u256 {
            let mut storage = self.storage(FREE_BLOBERT_NAMESPACE_HASH);
            storage.assert_caller_has_permission(Role::CollectionMinter);
            let token_id = uuid().into();
            storage.set_blobert_token(token_id, player, attributes);
            return_value(token_id)
        }

        fn admin_mint_seed(
            ref self: ContractState,
            player: ContractAddress,
            background: u32,
            armour: u32,
            jewelry: u32,
            mask: u32,
            weapon: u32,
        ) -> u256 {
            self
                .admin_mint(
                    player,
                    TokenAttributes::Seed(Seed { background, armour, jewelry, mask, weapon }),
                )
        }
    }
}

