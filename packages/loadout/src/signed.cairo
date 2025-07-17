#[derive(Copy, Drop, Serde, PartialEq)]
pub struct Signed<T> {
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
