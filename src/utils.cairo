use core::{
    num::traits::Bounded, hash::{HashStateTrait, HashStateExTrait, Hash},
    poseidon::{PoseidonTrait, HashState, poseidon_hash_span},
    fmt::{Display, Formatter, Error, Debug}, GasBuiltin
};
use starknet::{
    ContractAddress, get_contract_address, get_caller_address, get_tx_info, get_block_timestamp,
    StorageAddress, StorageBaseAddress, syscalls::{storage_read_syscall, storage_write_syscall},
    storage_address_from_base
};
use blob_arena::core::Felt252BitAnd;


fn hash_value<T, +Hash<T, HashState>, +Drop<T>>(value: T) -> felt252 {
    PoseidonTrait::new().update_with(value).finalize()
}

fn felt252_to_uuid(value: felt252) -> u128 {
    (value & Bounded::<u128>::MAX.into()).try_into().unwrap()
}

fn value_to_uuid<T, +Hash<T, HashState>, +Drop<T>>(value: T) -> u128 {
    felt252_to_uuid(hash_value(value))
}

fn uuid() -> felt252 {
    let storage_address: StorageAddress = 'uuid'.try_into().unwrap();
    let value = storage_read(storage_address) + 1;
    storage_write(storage_address, value);
    hash_value((get_contract_address(), value))
}

fn storage_read(address: StorageAddress) -> felt252 {
    storage_read_syscall(0, address).unwrap()
}

fn storage_write(address: StorageAddress, value: felt252) {
    storage_write_syscall(0, address, value).unwrap()
}


impl ArrayHash<
    T, S, +HashStateTrait<S>, +Hash<T, S>, +Drop<Array<T>>, +Drop<S>
> of Hash<Array<T>, S> {
    fn update_state(mut state: S, mut value: Array<T>) -> S {
        loop {
            match value.pop_front() {
                Option::Some(v) => { state = Hash::update_state(state, v); },
                Option::None => { break; },
            }
        };
        state
    }
}

fn array_to_hash_state<T, +Hash<T, HashState>, +Drop<Array<T>>,>(arr: Array<T>) -> HashState {
    Hash::update_state(PoseidonTrait::new(), arr)
}

fn make_hash_state<T, +Hash<T, HashState>, +Drop<T>>(value: T) -> HashState {
    PoseidonTrait::new().update_with(value)
}

trait ToHash<T> {
    fn update_to(self: @HashState, value: T) -> felt252;
}

fn felt252_to_u128(value: felt252) -> u128 {
    Into::<felt252, u256>::into(value).low
}

impl TToHashImpl<T, +Hash<T, HashState>, +Drop<T>> of ToHash<T> {
    fn update_to(self: @HashState, value: T) -> felt252 {
        (*self).update_with(value).finalize()
    }
}

trait UpdateHashToU128 {
    fn to_u128(self: HashState) -> u128;
    fn update_to_u128<T, +Hash<T, HashState>>(self: HashState, value: T) -> u128;
}

impl HashToU128Impl of UpdateHashToU128 {
    fn to_u128(self: HashState) -> u128 {
        felt252_to_u128(self.finalize())
    }
    fn update_to_u128<T, +Hash<T, HashState>>(self: HashState, value: T) -> u128 {
        Self::to_u128(Hash::update_state(self, value))
    }
}

impl TDebugImpl<T, +Display<T>> of Debug<T> {
    fn fmt(self: @T, ref f: Formatter) -> Result<(), Error> {
        Display::fmt(self, ref f)
    }
}

fn default_namespace() -> @ByteArray {
    @"blob_arena"
}
