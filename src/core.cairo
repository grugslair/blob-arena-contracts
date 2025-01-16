use core::{
    traits::Neg, num::traits::{Bounded, Zero, One, OverflowingSub, OverflowingAdd, OverflowingMul},
    cmp::{min, max}
};

#[derive(Copy, Drop)]
type TTupleSize5<T> = (T, T, T, T, T);

trait BoundedT<T, S> {
    fn min() -> S;
    fn max() -> S;
}

impl BoundedTImpl<T, S, +Bounded<T>, +TryInto<T, S>> of BoundedT<T, S> {
    fn min() -> S {
        Bounded::<T>::MIN.try_into().unwrap()
    }

    fn max() -> S {
        Bounded::<T>::MAX.try_into().unwrap()
    }
}

pub trait SaturatingInto<T, S> {
    fn saturating_into(self: T) -> S;
}

pub trait SaturatingAdd<T> {
    /// Saturating addition. Computes `self + other`, saturating at the relevant high or low
    /// boundary of the type.
    fn saturating_add(self: T, other: T) -> T;
}

/// Performs subtraction that saturates at the numeric bounds instead of overflowing.
pub trait SaturatingSub<T> {
    /// Saturating subtraction. Computes `self - other`, saturating at the relevant high or low
    /// boundary of the type.
    fn saturating_sub(self: T, other: T) -> T;
}

/// Performs multiplication that saturates at the numeric bounds instead of overflowing.
pub trait SaturatingMul<T> {
    /// Saturating multiplication. Computes `self * other`, saturating at the relevant high or low
    /// boundary of the type.
    fn saturating_mul(self: T, other: T) -> T;
}

pub impl TSaturatingAdd<
    T, +Drop<T>, +Copy<T>, +OverflowingAdd<T>, +Bounded<T>, +Zero<T>, +PartialOrd<T>
> of SaturatingAdd<T> {
    fn saturating_add(self: T, other: T) -> T {
        let (result, overflow) = self.overflowing_add(other);
        match overflow {
            true => { if other < Zero::zero() {
                Bounded::MIN
            } else {
                Bounded::MAX
            } },
            false => result,
        }
    }
}

pub impl TSaturatingSub<
    T, +Drop<T>, +Copy<T>, +OverflowingSub<T>, +Bounded<T>, +Zero<T>, +PartialOrd<T>
> of SaturatingSub<T> {
    fn saturating_sub(self: T, other: T) -> T {
        let (result, overflow) = self.overflowing_sub(other);
        match overflow {
            true => { if other < Zero::zero() {
                Bounded::MAX
            } else {
                Bounded::MIN
            } },
            false => result,
        }
    }
}


pub impl TSaturatingMul<
    T, +Drop<T>, +Copy<T>, +OverflowingMul<T>, +Bounded<T>, +Zero<T>, +PartialOrd<T>
> of SaturatingMul<T> {
    fn saturating_mul(self: T, other: T) -> T {
        let (result, overflow) = self.overflowing_mul(other);
        match overflow {
            true => {
                if (self < Zero::zero()) == (other < Zero::zero()) {
                    Bounded::MAX
                } else {
                    Bounded::MIN
                }
            },
            false => result,
        }
    }
}

pub impl TSaturatingIntoS<
    T, S, +Drop<T>, +Copy<T>, +TryInto<T, S>, +Bounded<S>, +BoundedT<S, T>, +PartialOrd<T>, +Zero<T>
> of SaturatingInto<T, S> {
    fn saturating_into(self: T) -> S {
        match self.try_into() {
            Option::Some(value) => value,
            Option::None => { if self > Zero::zero() {
                Bounded::MAX
            } else {
                Bounded::MIN
            } }
        }
    }
}

impl ArrayTryIntoFixed2Array<T, +Drop<T>> of TryInto<Array<T>, [T; 2]> {
    fn try_into(mut self: Array<T>) -> Option<[T; 2]> {
        if self.len() == 2 {
            Option::Some([self.pop_front().unwrap(), self.pop_front().unwrap()])
        } else {
            Option::None
        }
    }
}

impl Felt252BitAnd of BitAnd<felt252> {
    #[inline(always)]
    fn bitand(lhs: felt252, rhs: felt252) -> felt252 {
        (Into::<felt252, u256>::into(lhs) & rhs.into()).try_into().unwrap()
    }
}

fn in_range<T, +PartialOrd<T>, +Drop<T>, +Copy<T>>(lower: T, upper: T, value: T) -> T {
    max(lower, min(upper, value))
}

#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
struct Signed<T> {
    value: T,
    sign: bool,
}

impl SignedIntoI<T, S, +TryInto<T, S>, +Neg<S>> of Into<Signed<T>, S> {
    fn into(self: Signed<T>) -> S {
        if self.sign {
            Neg::<S>::neg(self.value.try_into().unwrap())
        } else {
            self.value.try_into().unwrap()
        }
    }
}

impl SignedTryIntoI<T, S, +TryInto<T, S>, +Neg<S>> of TryInto<Signed<T>, S> {
    fn try_into(self: Signed<T>) -> Option<S> {
        let value: S = self.value.try_into().unwrap();
        Option::Some(if self.sign {
            Neg::<S>::neg(value)
        } else {
            value
        })
    }
}

impl BoolIntoFelt252Impl of Into<bool, felt252> {
    fn into(self: bool) -> felt252 {
        if self {
            1
        } else {
            0
        }
    }
}

impl Felt252IntoBoolImpl of Into<felt252, bool> {
    fn into(self: felt252) -> bool {
        self != 0
    }
}

impl Felt252TryIntoBoolImpl of TryInto<felt252, bool> {
    fn try_into(self: felt252) -> Option<bool> {
        match self {
            0 => Option::Some(false),
            1 => Option::Some(true),
            _ => Option::None,
        }
    }
}
impl ArrayTryIntoTTupleSized2<T, +Drop<T>, +Copy<T>> of TryInto<Array<T>, (T, T)> {
    fn try_into(self: Array<T>) -> Option<(T, T)> {
        if self.len() == 2 {
            Option::Some((*self[0], *self[1]))
        } else {
            Option::None
        }
    }
}

impl TTupleSized2IntoFixed<T, +Drop<T>> of Into<(T, T), [T; 2]> {
    fn into(self: (T, T)) -> [T; 2] {
        let (a, b) = self;
        [a, b]
    }
}

impl TTupleSized2ToSpan<T, +Drop<T>, +Copy<T>> of ToSpanTrait<(T, T), T> {
    fn span(self: @(T, T)) -> Span<T> {
        let (a, b) = *self;
        array![a, b].span()
    }
}

trait Sum<T, S> {
    fn sum(self: T) -> S;
}


impl SumTArray<S, +Add<S>, +Zeroable<S>, +Drop<S>> of Sum<Array<S>, S> {
    fn sum(self: Array<S>) -> S {
        let mut result = Zeroable::<S>::zero();
        for value in self {
            result = result + value;
        };
        result
    }
}


trait Enumerate<T, S> {
    fn enumerate(self: T) -> Array<(usize, S)>;
}

impl EnumerateArrayImpl<S, +Drop<S>> of Enumerate<Array<S>, S> {
    fn enumerate(mut self: Array<S>) -> Array<(usize, S)> {
        let mut result = ArrayTrait::<(usize, S)>::new();
        let mut n = 0;
        loop {
            match self.pop_front() {
                Option::Some(value) => {
                    result.append((n, value));
                    n += 1;
                },
                Option::None => { break; },
            }
        };
        result
    }
}
