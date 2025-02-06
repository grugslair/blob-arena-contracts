use core::iter::{Iterator, IntoIterator, traits::iterator::IteratorIntoIterator};
use core::ops::Fn;

#[must_use]
#[derive(Drop, Clone, Debug)]
pub struct Enumerator<I> {
    iter: I,
    count: usize,
}

trait Iteration<T> {
    type IntoIter;
    type Item;
    fn enumerate(self: T) -> Enumerator<Self::IntoIter>;
    fn map<F, O, +Fn<F, O>>(self: T, f: F) -> Mapper<Self::IntoIter, F>;
    fn zip<U, +IntoIterator<U>, +Destruct<U>>(
        self: T, other: U,
    ) -> Zipper<Self::IntoIter, IntoIterator::<U>::IntoIter>;
}

impl IterationImpl<T, +IntoIterator<T>, +Destruct<T>> of Iteration<T> {
    type IntoIter = IntoIterator::<T>::IntoIter;
    type Item = IntoIterator::<T>::Iterator::Item;
    fn enumerate(self: T) -> Enumerator<Self::IntoIter> {
        Enumerator { iter: self.into_iter(), count: 0 }
    }
    fn map<F, O, +Fn<F, O>>(self: T, f: F) -> Mapper<Self::IntoIter, F> {
        Mapper { iter: self.into_iter(), f }
    }
    fn zip<U, +IntoIterator<U>, +Destruct<U>>(
        self: T, other: U,
    ) -> Zipper<Self::IntoIter, IntoIterator::<U>::IntoIter> {
        Zipper { iter: self.into_iter(), other: other.into_iter() }
    }
}

pub trait Enumerate<T> {
    type IntoIter;
    fn enumerate(self: T) -> Enumerator<Self::IntoIter>;
}
pub impl EnumerateImpl<T, +IntoIterator<T>> of Enumerate<T> {
    type IntoIter = IntoIterator::<T>::IntoIter;
    fn enumerate(self: T) -> Enumerator<Self::IntoIter> {
        Enumerator { iter: self.into_iter(), count: 0 }
    }
}

pub impl EnumerateIterator<I, impl TIter: Iterator<I>, +Destruct<I>> of Iterator<Enumerator<I>> {
    type Item = (usize, Iterator::<I>::Item);

    /// # Overflow Behavior
    ///
    /// The method does no guarding against overflows, so enumerating more than
    /// `Bounded::<usize>::MAX` elements will always panic.
    ///
    /// [`Bounded`]: core::num::traits::Bounded
    ///
    /// # Panics
    ///
    /// Will panic if the index of the element overflows a `usize`.
    #[inline]
    fn next(ref self: Enumerator<I>) -> Option<Self::Item> {
        let i = self.count;
        self.count += 1;
        Option::Some((i, self.iter.next()?))
    }
}

pub impl EnumeratorIntoIterator<I, impl TIter: Iterator<I>, +Destruct<I>> =
    IteratorIntoIterator<Enumerator<I>>;

/// An iterator that maps the values of `iter` with `f`.
///
/// This `struct` is created by the [`map`] method on [`Iterator`]. See its
/// documentation for more.
///
/// [`map`]: Iterator::map
/// [`Iterator`]: core::iter::Iterator
///
#[must_use]
#[derive(Drop, Clone)]
pub struct Mapper<I, F> {
    iter: I,
    f: F,
}

pub trait Map<T, F> {
    type IntoIter;
    fn map(self: T, f: F) -> Mapper<T, F>;
}

pub impl MapImpl<T, F, O, +IntoIterator<T>, +Fn<F, O>, +Destruct<F>> of Map<T, F> {
    type IntoIter = IntoIterator::<T>::IntoIter;
    fn map(self: T, f: F) -> Mapper<T, F> {
        Mapper { iter: self, f }
    }
}

pub impl MapIterator<
    I, F, impl TIter: Iterator<I>, impl func: Fn<F, TIter::Item>, +Destruct<I>, +Destruct<F>,
> of Iterator<Mapper<I, F>> {
    type Item = func::Output;
    fn next(ref self: Mapper<I, F>) -> Option<func::Output> {
        Option::Some(self.f.call(self.iter.next()?))
    }
}

pub impl MapperIntoIterator<
    I, F, impl TIter: Iterator<I>, impl func: Fn<F, TIter::Item>, +Destruct<I>, +Destruct<F>,
> =
    IteratorIntoIterator<Mapper<I, F>>;

#[must_use]
#[derive(Drop, Clone)]
struct Zipper<I, J> {
    iter: I,
    other: J,
}
