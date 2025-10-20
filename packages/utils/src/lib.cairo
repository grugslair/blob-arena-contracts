use calls::ExternalCalls;
use core::hash::HashStateTrait;
use core::integer::u128_safe_divmod;
use core::num::traits::{DivRem, Zero};
pub use core::ops::DivAssign;
use core::poseidon::{HashState, poseidon_hash_span};
use sai_core_utils::{poseidon_hash_single, poseidon_hash_two};
use starknet::syscalls::{storage_read_syscall, storage_write_syscall};
use starknet::{ContractAddress, StorageAddress, SyscallResultTrait, get_contract_address};
pub mod bytes;
pub mod calls;
pub mod storage;
pub mod vrf;
const UUID_STORAGE_ADDRESS_FELT: felt252 = selector!("__uuid__");

#[generate_trait]
pub impl SeedProbabilityImpl of SeedProbability {
    fn get_outcome<T, +Into<T, u128>, +Drop<T>>(
        ref self: u128, scale: u128, probability: T,
    ) -> bool {
        let (seed, value) = self.div_rem(scale.try_into().unwrap());
        self = seed;
        value < probability.into()
    }
    fn get_value<T, +Into<T, u128>, +TryInto<u128, T>, +Zero<T>>(ref self: u128, scale: T) -> T {
        let scale: NonZero<u128> = match Into::<_, u128>::into(scale).try_into() {
            None => { return Zero::zero(); },
            Some(s) => s,
        };
        let (seed, value) = self.div_rem(scale);
        self = seed;
        value.try_into().unwrap()
    }
    fn get_final_value<T, +Into<T, u128>, +TryInto<u128, T>>(self: u128, scale: T) -> T {
        let (_, value) = self.div_rem(Into::<T, u128>::into(scale).try_into().unwrap());

        value.try_into().unwrap()
    }
}

pub fn felt252_to_u128(value: felt252) -> u128 {
    Into::<felt252, u256>::into(value).low
}

#[derive(Copy, Drop, Serde)]
pub struct Randomness {
    seed: felt252,
    randomness: u256,
}

#[generate_trait]
pub impl RandomnessImpl of RandomnessTrait {
    fn new(seed: felt252) -> Randomness {
        Randomness { seed, randomness: seed.into() }
    }

    fn get<T, +Into<T, u256>, +TryInto<u256, T>>(ref self: Randomness, scale: T) -> T {
        let scale_t: u256 = scale.into();
        if self.randomness < scale_t {
            self.next();
        }
        let (randomness, value) = DivRem::div_rem(self.randomness, scale_t.try_into().unwrap());
        self.randomness = randomness;
        value.try_into().unwrap()
    }

    fn get_bool(ref self: Randomness) -> bool {
        if self.randomness < 2 {
            self.next();
        }
        let (randomness, value) = DivRem::div_rem(self.randomness, 2_u256.try_into().unwrap());
        self.randomness = randomness;
        return value == 1_u256;
    }

    fn final<T, +Into<T, u256>, +TryInto<u256, T>>(ref self: Randomness, scale: T) -> T {
        let scale_t: u256 = scale.into();
        if self.randomness < scale_t {
            self.next();
        }
        (self.randomness / scale_t.into()).try_into().unwrap()
    }

    fn next(ref self: Randomness) {
        self.seed = poseidon_hash_single(self.seed);
        self.randomness = self.seed.into();
    }
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

