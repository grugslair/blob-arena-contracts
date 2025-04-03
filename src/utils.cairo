use core::{
    num::traits::Bounded, hash::{HashStateTrait, HashStateExTrait, Hash},
    poseidon::{PoseidonTrait, HashState, poseidon_hash_span},
    fmt::{Display, Formatter, Error, Debug}, integer::u128_safe_divmod
};
use starknet::{
    ContractAddress, get_contract_address, get_caller_address, get_tx_info, get_block_timestamp,
    StorageAddress, StorageBaseAddress, syscalls::{storage_read_syscall, storage_write_syscall},
    storage_address_from_base
};
use blob_arena::core::Felt252BitAnd;

fn storage_read(address: StorageAddress) -> felt252 {
    storage_read_syscall(0, address).unwrap()
}

fn storage_write(address: StorageAddress, value: felt252) {
    storage_write_syscall(0, address, value).unwrap()
}

fn get_transaction_hash() -> felt252 {
    get_tx_info().unbox().transaction_hash
}

impl TDebugImpl<T, +Display<T>> of Debug<T> {
    fn fmt(self: @T, ref f: Formatter) -> Result<(), Error> {
        Display::fmt(self, ref f)
    }
}


trait SeedProbability {
    fn get_outcome<T, +Into<T, u128>>(ref self: u128, scale: NonZero<u128>, probability: T) -> bool;
    fn get_value(ref self: u128, scale: NonZero<u128>) -> u128;
}

impl SeedProbabilityImpl of SeedProbability {
    fn get_outcome<T, +Into<T, u128>>(
        ref self: u128, scale: NonZero<u128>, probability: T
    ) -> bool {
        let (seed, value) = u128_safe_divmod(self, scale);
        self = seed;
        value < probability.into()
    }

    fn get_value(ref self: u128, scale: NonZero<u128>) -> u128 {
        let (seed, value) = u128_safe_divmod(self, scale);
        self = seed;
        value
    }
}

