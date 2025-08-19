use core::hash::HashStateTrait;
use core::integer::u128_safe_divmod;
use core::poseidon::{HashState, poseidon_hash_span};
use sai_core_utils::poseidon_hash_two;
use starknet::syscalls::{storage_read_syscall, storage_write_syscall};
use starknet::{ContractAddress, StorageAddress, SyscallResultTrait, get_contract_address};


const UUID_STORAGE_ADDRESS_FELT: felt252 = selector!("__uuid__");

#[generate_trait]
pub impl SeedProbabilityImpl of SeedProbability {
    fn get_outcome<T, +Into<T, u128>, +Drop<T>>(
        ref self: u128, scale: u128, probability: T,
    ) -> bool {
        let (seed, value) = u128_safe_divmod(self, scale.try_into().unwrap());
        self = seed;
        value < probability.into()
    }
    fn get_value<T, +Into<T, u128>, +TryInto<u128, T>>(ref self: u128, scale: T) -> T {
        let (seed, value) = u128_safe_divmod(
            self, Into::<T, u128>::into(scale).try_into().unwrap(),
        );
        self = seed;
        value.try_into().unwrap()
    }
    fn get_final_value<T, +Into<T, u128>, +TryInto<u128, T>>(self: u128, scale: T) -> T {
        let (_, value) = u128_safe_divmod(self, Into::<T, u128>::into(scale).try_into().unwrap());
        value.try_into().unwrap()
    }
}

pub fn felt252_to_u128(value: felt252) -> u128 {
    Into::<felt252, u256>::into(value).low
}


pub trait UpdateHashToU128 {
    fn to_u128(self: HashState) -> u128;
    fn update_to_u128<T, +Into<T, felt252>>(self: HashState, value: T) -> u128;
}

impl HashToU128Impl of UpdateHashToU128 {
    fn to_u128(self: HashState) -> u128 {
        felt252_to_u128(self.finalize())
    }
    fn update_to_u128<T, +Into<T, felt252>>(self: HashState, value: T) -> u128 {
        Self::to_u128(HashStateTrait::update(self, value.into()))
    }
}

pub fn uuid() -> felt252 {
    let storage_address: StorageAddress = UUID_STORAGE_ADDRESS_FELT.try_into().unwrap();
    let value = storage_read_syscall(0, storage_address).unwrap_syscall() + 1;
    storage_write_syscall(0, storage_address, value).unwrap_syscall();
    poseidon_hash_two(get_contract_address(), value)
}


pub fn erc721_token_hash(collection_address: ContractAddress, token_id: u256) -> felt252 {
    poseidon_hash_span(
        [collection_address.into(), token_id.low.into(), token_id.high.into()].span(),
    )
}
