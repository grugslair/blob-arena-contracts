use core::hash::{Hash, HashStateTrait};
use core::integer::u128_safe_divmod;
use core::poseidon::HashState;

pub trait SeedProbability {
    fn get_outcome<T, +Into<T, u128>, +Drop<T>>(
        ref self: u128, scale: u128, probability: T,
    ) -> bool;
    fn get_value(ref self: u128, scale: u128) -> u128;
}

pub impl SeedProbabilityImpl of SeedProbability {
    fn get_outcome<T, +Into<T, u128>, +Drop<T>>(
        ref self: u128, scale: u128, probability: T,
    ) -> bool {
        let (seed, value) = u128_safe_divmod(self, scale.try_into().unwrap());
        self = seed;
        value < probability.into()
    }

    fn get_value(ref self: u128, scale: u128) -> u128 {
        let (seed, value) = u128_safe_divmod(self, scale.try_into().unwrap());
        self = seed;
        value
    }
}

pub fn felt252_to_u128(value: felt252) -> u128 {
    Into::<felt252, u256>::into(value).low
}


pub trait UpdateHashToU128 {
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
