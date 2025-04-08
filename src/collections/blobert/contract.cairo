const BLOBERT_NAMESPACE_HASH: felt252 = bytearray_hash!("blobert");

#[dojo::contract]
mod blobert_actions {
    use starknet::{ContractAddress, get_contract_address, contract_address_const};
    use dojo::world::{WorldStorage, IWorldDispatcher};
    use crate::world::WorldTrait;
    use crate::erc721::erc721_owner_of;
    use crate::storage::read_value_from_felt252;
    use super::BLOBERT_NAMESPACE_HASH;
    use super::super::{IBlobertDispatcher, IBlobertDispatcherTrait};
    use super::super::super::{
        BlobertStore, TokenAttributes, ICollection, CollectionGroupStorage, CollectionGroup,
    };
    use super::super::super::items::cmp;
    use super::super::super::collection;

    const BLOBERT_CONTRACT_ADDRESS_STORAGE_FELT: felt252 =
        0x01ff9815cb29fa806ce61ec4c9993e335d26c8e9ae86fe2daef6cc7bbfb5db3d;

    fn dojo_init(ref self: ContractState, blobert_contract_address: ContractAddress) {
        self.blobert_contract_address.write(blobert_contract_address);
        let mut storage = self.default_storage();
        storage.set_collection_group(get_contract_address(), CollectionGroup::ClassicBlobert);
    }

    #[storage]
    struct Storage {
        blobert_contract_address: ContractAddress,
    }

    fn blobert_dispatcher() -> IBlobertDispatcher {
        let contract_address = read_value_from_felt252(BLOBERT_CONTRACT_ADDRESS_STORAGE_FELT);
        IBlobertDispatcher { contract_address }
    }


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

