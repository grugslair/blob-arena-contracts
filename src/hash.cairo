use core::{
    num::traits::One, hash::{Hash, HashStateExTrait, HashStateTrait},
    poseidon::{HashState, PoseidonTrait, poseidon_hash_span}
};

trait HashUpdate<T> {
    fn update_hash_state(ref self: HashState, value: T);
}

impl HashUpdateImpl<T, +Hash<T, HashState>, +Drop<T>> of HashUpdate<T> {
    fn update_hash_state(ref self: HashState, value: T) {
        self = Hash::update_state(self, value);
    }
}

impl ArrayHash<
    T, S, +hash::HashStateTrait<S>, +hash::Hash<T, S>, +Drop<Array<T>>, +Drop<S>
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

impl SpanHash<
    T, S, +hash::HashStateTrait<S>, +hash::Hash<T, S>, +Drop<Array<T>>, +Drop<S>, +Copy<T>,
> of Hash<Span<T>, S> {
    fn update_state(mut state: S, mut value: Span<T>) -> S {
        loop {
            match value.pop_front() {
                Option::Some(v) => { state = Hash::update_state(state, *v); },
                Option::None => { break; },
            }
        };
        state
    }
}

fn hash_value<T, +Hash<T, HashState>, +Drop<T>>(value: T) -> felt252 {
    PoseidonTrait::new().update_with(value).finalize()
}

fn value_to_id<T, +Serde<T>>(value: @T) -> felt252 {
    let mut arr = ArrayTrait::<felt252>::new();
    Serde::serialize(value, ref arr);

    if arr.len().is_one() {
        arr.pop_front().unwrap()
    } else {
        poseidon_hash_span(arr.span())
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


fn in_order<T, +PartialOrd<T>, +PartialEq<T>, +Drop<T>>(a: T, b: T, hash: HashState) -> bool {
    if a == b {
        (hash.to_u128() % 2_u128).is_zero()
    } else {
        a < b
    }
}
