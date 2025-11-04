use core::metaprogramming::TypeEqual;
use core::num::traits::{Bounded, DivRem, Zero};
pub use core::ops::DivAssign;
pub use sai_core_utils::BoundedCast;
use sai_core_utils::poseidon_hash_single;


const U8_MAX_U256: u256 = Bounded::<u8>::MAX.into();
const U16_MAX_U256: u256 = Bounded::<u16>::MAX.into();
const U32_MAX_U256: u256 = Bounded::<u32>::MAX.into();
const U64_MAX_U256: u256 = Bounded::<u64>::MAX.into();
const U128_MAX_U256: u256 = Bounded::<u128>::MAX.into();

const U8_MAX_U256_NZ: NonZero<u256> = 0xff;
const U16_MAX_U256_NZ: NonZero<u256> = 0xffff;
const U32_MAX_U256_NZ: NonZero<u256> = 0xffffffff;
const U64_MAX_U256_NZ: NonZero<u256> = 0xffffffffffffffff;
const U128_MAX_U256_NZ: NonZero<u256> = 0xffffffffffffffffffffffffffffffff;

pub trait SeedProbability<S, T> {
    fn get_outcome(ref self: S, scale: T, probability: T) -> bool;
    fn get_outcome_nz(ref self: S, scale: NonZero<S>, probability: T) -> bool;
    fn get_value(ref self: S, scale: T) -> T;
    fn get_value_nz(ref self: S, scale: NonZero<S>) -> T;
    fn get_final_value(self: S, scale: T) -> T;
}


fn try_into_non_zero<S, T, +Into<T, S>, +TryInto<S, NonZero<S>>>(value: T) -> Option<NonZero<S>> {
    Into::<T, S>::into(value).try_into()
}

pub impl SeedProbabilityImpl<
    S,
    T,
    +DivRem<S, S>,
    +TypeEqual<DivRem::<S>::Quotient, S>,
    +TypeEqual<DivRem::<S>::Remainder, S>,
    +Rem<S>,
    +Into<T, S>,
    +TryInto<S, NonZero<S>>,
    +TryInto<S, T>,
    +Drop<T>,
    +Drop<S>,
    +PartialOrd<T>,
    +Zero<T>,
> of SeedProbability<S, T> {
    fn get_outcome(ref self: S, scale: T, probability: T) -> bool {
        Self::get_outcome_nz(ref self, try_into_non_zero(scale).unwrap(), probability)
    }
    fn get_outcome_nz(ref self: S, scale: NonZero<S>, probability: T) -> bool {
        Self::get_value_nz(ref self, scale) < probability
    }
    fn get_value(ref self: S, scale: T) -> T {
        let scale: NonZero<S> = match try_into_non_zero(scale) {
            None => { return Zero::zero(); },
            Some(s) => s,
        };
        Self::get_value_nz(ref self, scale)
    }
    fn get_value_nz(ref self: S, scale: NonZero<S>) -> T {
        let (seed, value) = self.div_rem(scale);
        self = seed;
        value.try_into().unwrap()
    }
    fn get_final_value(self: S, scale: T) -> T {
        (self % scale.into()).try_into().unwrap()
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
        value == 1_u256
    }

    fn get_u8(ref self: Randomness) -> u8 {
        if self.randomness < U8_MAX_U256 {
            self.next();
        }
        let (randomness, value) = DivRem::div_rem(self.randomness, U8_MAX_U256_NZ);
        self.randomness = randomness;
        value.try_into().unwrap()
    }

    fn get_u16(ref self: Randomness) -> u16 {
        if self.randomness < U16_MAX_U256 {
            self.next();
        }
        let (randomness, value) = DivRem::div_rem(self.randomness, U16_MAX_U256_NZ);
        self.randomness = randomness;
        value.try_into().unwrap()
    }

    fn get_u32(ref self: Randomness) -> u32 {
        if self.randomness < U32_MAX_U256 {
            self.next();
        }
        let (randomness, value) = DivRem::div_rem(self.randomness, U32_MAX_U256_NZ);
        self.randomness = randomness;
        value.try_into().unwrap()
    }

    fn get_u64(ref self: Randomness) -> u64 {
        if self.randomness < U64_MAX_U256 {
            self.next();
        }
        let (randomness, value) = DivRem::div_rem(self.randomness, U64_MAX_U256_NZ);
        self.randomness = randomness;
        value.try_into().unwrap()
    }

    fn get_u128(ref self: Randomness) -> u128 {
        if self.randomness < U128_MAX_U256 {
            self.next();
        }
        let (randomness, value) = DivRem::div_rem(self.randomness, U128_MAX_U256_NZ);
        self.randomness = randomness;
        value.try_into().unwrap()
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

