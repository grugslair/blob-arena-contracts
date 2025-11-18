pub use sai_core_utils::BoundedCast;
use sai_core_utils::{poseidon_hash_three, poseidon_hash_two};
use starknet::syscalls::{storage_read_syscall, storage_write_syscall};
use starknet::{ContractAddress, StorageAddress, SyscallResultTrait, get_contract_address};
pub mod calls;
pub mod random;
pub mod storage;
pub mod vrf;
pub use calls::ExternalCalls;
pub use random::{Randomness, RandomnessTrait, SeedProbability};
pub use vrf::VrfTrait;
const UUID_STORAGE_ADDRESS_FELT: felt252 = selector!("__uuid__");


pub fn felt252_to_u128(value: felt252) -> u128 {
    Into::<felt252, u256>::into(value).low
}

pub fn uuid() -> felt252 {
    let storage_address: StorageAddress = UUID_STORAGE_ADDRESS_FELT.try_into().unwrap();
    let value = storage_read_syscall(0, storage_address).unwrap_syscall() + 1;
    storage_write_syscall(0, storage_address, value).unwrap_syscall();
    poseidon_hash_two(get_contract_address(), value)
}


pub fn erc721_token_hash(collection_address: ContractAddress, token_id: u256) -> felt252 {
    poseidon_hash_three(collection_address, token_id.low, token_id.high)
}


pub trait CapInto<T, S> {
    fn cap_into(self: T, cap: S) -> S;
}

pub trait IntoRange<T, S> {
    fn into_range(self: T, min: S, max: S) -> S;
}

impl CapIntoImpl<
    T, S, +Drop<T>, +Drop<S>, +Copy<T>, +Copy<S>, +Into<S, T>, +TryInto<T, S>, +PartialOrd<T>,
> of CapInto<T, S> {
    fn cap_into(self: T, cap: S) -> S {
        if self > cap.into() {
            cap
        } else {
            self.try_into().unwrap()
        }
    }
}


impl IntoRangeImpl<
    T, S, +Drop<T>, +Drop<S>, +Copy<T>, +Copy<S>, +Into<S, T>, +TryInto<T, S>, +PartialOrd<T>,
> of IntoRange<T, S> {
    fn into_range(self: T, min: S, max: S) -> S {
        if self < min.into() {
            min
        } else if self > max.into() {
            max
        } else {
            self.try_into().unwrap()
        }
    }
}
pub impl BoolIntoU8 of Into<bool, u8> {
    fn into(self: bool) -> u8 {
        if self {
            1_u8
        } else {
            0_u8
        }
    }
}

