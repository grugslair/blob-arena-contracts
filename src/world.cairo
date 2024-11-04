use starknet::{get_caller_address, ContractAddress, get_contract_address, StorageAddress};
use dojo::{world::WorldStorage, contract::{IContractDispatcherTrait, IContractDispatcher}};

use blob_arena::{utils::{storage_read, storage_write}, hash::hash_value};

fn uuid() -> felt252 {
    let storage_address: StorageAddress = 'uuid'.try_into().unwrap();
    let value = storage_read(storage_address) + 1;
    storage_write(storage_address, value);
    hash_value((get_contract_address(), value))
}


#[generate_trait]
impl WorldImpl of WorldTrait {
    fn assert_caller_is_owner(self: @WorldStorage) -> ContractAddress {
        let dispatcher = IContractDispatcher { contract_address: get_contract_address(), };
        let selector = dispatcher.selector();
        let caller = get_caller_address();
        assert((*self).is_owner(selector, caller), 'Not Admin');
        caller
    }
}

