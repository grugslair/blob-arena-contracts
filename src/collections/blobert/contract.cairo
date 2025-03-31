const BLOBERT_NAMESPACE_HASH: felt252 = bytearray_hash!("blobert");

#[dojo::contract]
mod blobert_actions {
    use starknet::{ContractAddress, get_contract_address, contract_address_const};
    use dojo::world::{WorldStorage, IWorldDispatcher};
    use crate::world::WorldTrait;
    use crate::erc721::erc721_owner_of;
    use super::BLOBERT_NAMESPACE_HASH;
    use super::super::{blobert_dispatcher, IBlobertDispatcherTrait};
    use super::super::super::{BlobertStore, TokenAttributes, ICollection};
    use super::super::super::items::cmp;
    use super::super::super::collection;

    impl BlobertStoreImpl of BlobertStore {
        fn local_store(self: @IWorldDispatcher) -> WorldStorage {
            self.storage(BLOBERT_NAMESPACE_HASH)
        }

        fn item_store(self: @IWorldDispatcher) -> WorldStorage {
            Self::local_store(self)
        }

        fn attributes(self: @IWorldDispatcher, token_id: u256) -> TokenAttributes {
            blobert_dispatcher().traits(token_id)
        }

        fn owner(self: @IWorldDispatcher, token_id: u256) -> ContractAddress {
            blobert_dispatcher().owner_of(token_id)
        }
    }


    #[abi(embed_v0)]
    impl IBlobertItems = cmp::IBlobertItemsImpl<ContractState, BlobertStoreImpl>;

    #[abi(embed_v0)]
    impl IBlobertCollection =
        collection::IBlobertCollectionImpl<ContractState, BlobertStoreImpl>;
}

