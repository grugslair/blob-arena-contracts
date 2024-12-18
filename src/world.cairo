use starknet::{get_caller_address, ContractAddress, get_contract_address, StorageAddress};
use dojo::{
    world::{WorldStorage, IWorldDispatcherTrait},
    contract::{IContractDispatcherTrait, IContractDispatcher}
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

fn default_namespace() -> @ByteArray {
    @"blob_arena"
}


pub trait DefaultStorage<TContractState> {
    fn default_storage(self: @TContractState) -> WorldStorage;
}

