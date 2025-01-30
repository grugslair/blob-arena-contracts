use starknet::{get_caller_address, ContractAddress, get_contract_address, StorageAddress};
use dojo::{
    world::{WorldStorage, IWorldDispatcherTrait}, model::{Model, ModelIndex},
    contract::{IContractDispatcherTrait, IContractDispatcher},
    utils::{deserialize_unwrap, entity_id_from_keys}, meta::{Introspect, Layout, FieldLayout},
};

use blob_arena::{utils::{storage_read, storage_write}, hash::hash_value};

fn uuid() -> felt252 {
    let storage_address: StorageAddress = 'uuid'.try_into().unwrap();
    let value = storage_read(storage_address) + 1;
    storage_write(storage_address, value);
    hash_value((get_contract_address(), value))
}

fn incrementor(key: felt252) -> felt252 {
    let storage_address: StorageAddress = key.try_into().unwrap();
    let value = storage_read(storage_address) + 1;
    storage_write(storage_address, value);
    value
}


#[generate_trait]
impl WorldImpl of WorldTrait {
    fn assert_caller_is_creator(self: @WorldStorage) -> ContractAddress {
        let caller = get_caller_address();
        assert((*self.dispatcher).is_owner(0, caller), 'Not Admin');
        caller
    }
    fn assert_caller_is_admin(self: @WorldStorage, selector_hash: felt252) -> ContractAddress {
        let caller = get_caller_address();
        assert((*self.dispatcher).is_writer(selector_hash, caller), 'Not Admin');
        caller
    }
}

#[generate_trait]
impl WorldStorageImpl of LayoutStorage {
    fn read_nested_member<M, L, T, K, +Model<M>, +Introspect<L>, +Serde<T>, +Serde<K>>(
        self: @WorldStorage, keys: @K, selectors: Span<felt252>,
    ) -> T {
        let (mut entity_id, mut member_id) = (entity_id_from_keys(keys), *selectors.at(0));
        for n in 1..(selectors.len()) {
            entity_id = dojo::utils::combine_key(entity_id, member_id);
            member_id = *selectors.at(n);
        };

        deserialize_unwrap(
            IWorldDispatcherTrait::entity(
                *self.dispatcher,
                Model::<M>::selector(*self.namespace_hash),
                ModelIndex::MemberId((entity_id, member_id)),
                Introspect::<L>::layout(),
            ),
        )
    }
    fn read_member_from_layout<M, L, T, K, +Model<M>, +Introspect<L>, +Serde<T>, +Serde<K>>(
        self: @WorldStorage, keys: @K, selector: felt252,
    ) {
        deserialize_unwrap(
            IWorldDispatcherTrait::entity(
                *self.dispatcher,
                Model::<M>::selector(*self.namespace_hash),
                ModelIndex::MemberId((entity_id_from_keys(keys), selector)),
                Introspect::<L>::layout(),
            ),
        )
    }
}

fn default_namespace() -> @ByteArray {
    @"blob_arena"
}


pub trait DefaultStorage<TContractState> {
    fn default_storage(self: @TContractState) -> WorldStorage;
}

