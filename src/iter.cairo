use core::iter::{Iterator, IntoIterator, traits::iterator::IteratorIntoIterator};
use core::ops::Fn;


pub trait Iteration<T> {
    type IntoIter;
    type Item;
    fn enumerate(self: T) -> Enumerator<Self::IntoIter>;
    fn map<F, O, +Fn<F, O>, +Destruct<F>>(self: T, f: F) -> Mapper<Self::IntoIter, F>;
    fn zip<U, +IntoIterator<U>, +Destruct<U>>(
        self: T, other: U,
    ) -> Zipper<Self::IntoIter, IntoIterator::<U>::IntoIter>;
    fn filter<F, +Fn<F, bool>, +Destruct<F>>(self: T, filter: F) -> Filter<Self::IntoIter, F>;
    fn collect(self: T) -> Array<Self::Item>;
}

pub impl IntoIterationImpl<
    T,
    +IntoIterator<T>,
    +Destruct<T>,
    +Destruct<IntoIterator::<T>::IntoIter>,
    +Drop<IntoIterator::<T>::Iterator::Item>,
> of Iteration<T> {
    type IntoIter = IntoIterator::<T>::IntoIter;
    type Item = IntoIterator::<T>::Iterator::Item;
    fn enumerate(self: T) -> Enumerator<Self::IntoIter> {
        Enumerator { iter: self.into_iter(), count: 0 }
    }
    fn map<F, O, +Fn<F, O>, +Destruct<F>>(self: T, f: F) -> Mapper<Self::IntoIter, F> {
        Mapper { iter: self.into_iter(), f }
    }
    fn zip<U, +IntoIterator<U>, +Destruct<U>>(
        self: T, other: U,
    ) -> Zipper<Self::IntoIter, IntoIterator::<U>::IntoIter> {
        Zipper { iter: self.into_iter(), other: other.into_iter() }
    }
    fn filter<F, +Fn<F, bool>, +Destruct<F>>(self: T, filter: F) -> Filter<Self::IntoIter, F> {
        Filter { iter: self.into_iter(), filter }
    }
    fn collect(self: T) -> Array<Self::Item> {
        let mut iter = self.into_iter();
        let mut result = ArrayTrait::<Self::Item>::new();
        loop {
            match iter.next() {
                Option::Some(value) => { result.append(value); },
                Option::None => { break; },
            }
        };
        result
    }
}


pub impl IterationImpl<T, +Iterator<T>, +Destruct<T>, +Drop<Iterator::<T>::Item>> of Iteration<T> {
    type IntoIter = T;
    type Item = Iterator::<T>::Item;
    fn enumerate(self: T) -> Enumerator<Self::IntoIter> {
        Enumerator { iter: self, count: 0 }
    }
    fn map<F, O, +Fn<F, O>, +Destruct<F>>(self: T, f: F) -> Mapper<Self::IntoIter, F> {
        Mapper { iter: self, f }
    }
    fn zip<U, +IntoIterator<U>, +Destruct<U>>(
        self: T, other: U,
    ) -> Zipper<Self::IntoIter, IntoIterator::<U>::IntoIter> {
        Zipper { iter: self, other: other.into_iter() }
    }
    fn filter<F, +Fn<F, bool>, +Destruct<F>>(self: T, filter: F) -> Filter<Self::IntoIter, F> {
        Filter { iter: self, filter }
    }
    fn collect(self: T) -> Array<Self::Item> {
        let mut iter = self.into_iter();
        let mut result = ArrayTrait::<Self::Item>::new();
        loop {
            match iter.next() {
                Option::Some(value) => { result.append(value); },
                Option::None => { break; },
            }
        };
        result
    }
}

impl ArrayIteration<T, +Drop<T>> = IntoIterationImpl<Array<T>>;
impl SpanIteration<T, +Drop<T>> = IntoIterationImpl<Span<T>>;

#[must_use]
#[derive(Drop, Clone, Debug)]
pub struct Enumerator<I> {
    iter: I,
    count: usize,
}

// pub trait Enumerate<T> {
//     type IntoIter;
//     fn enumerate(self: T) -> Enumerator<Self::IntoIter>;
// }
// pub impl EnumerateImpl<T, +IntoIterator<T>> of Enumerate<T> {
//     type IntoIter = IntoIterator::<T>::IntoIter;
//     fn enumerate(self: T) -> Enumerator<Self::IntoIter> {
//         Enumerator { iter: self.into_iter(), count: 0 }
//     }
// }

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

// pub trait Map<T, F> {
//     type IntoIter;
//     fn map(self: T, f: F) -> Mapper<T, F>;
// }

// pub impl MapImpl<T, F, O, +IntoIterator<T>, +Fn<F, O>, +Destruct<F>> of Map<T, F> {
//     type IntoIter = IntoIterator::<T>::IntoIter;
//     fn map(self: T, f: F) -> Mapper<T, F> {
//         Mapper { iter: self, f }
//     }
// }

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
pub struct Filter<I, F> {
    pub iter: I,
    pub filter: F,
}

impl FilterIterator<
    I,
    F,
    impl TIter: Iterator<I>,
    +core::ops::Fn<F, @TIter::Item>[Output: bool],
    +Destruct<I>,
    +Destruct<F>,
    +Destruct<TIter::Item>,
> of Iterator<Filter<I, F>> {
    type Item = TIter::Item;
    fn next(ref self: Filter<I, F>) -> Option<Self::Item> {
        loop {
            match self.iter.next() {
                Option::Some(value) => if self.filter.call(@value) {
                    break Option::Some(value);
                },
                Option::None => { break Option::None; },
            }
        }
    }
}

#[must_use]
#[derive(Drop, Clone)]
struct Zipper<I, J> {
    iter: I,
    other: J,
}


impl ZipIterator<
    A,
    B,
    impl IterA: Iterator<A>,
    impl IterB: Iterator<B>,
    +Destruct<A>,
    +Destruct<B>,
    +Destruct<IterA::Item>,
    +Destruct<IterB::Item>,
> of Iterator<Zipper<A, B>> {
    type Item = (IterA::Item, IterB::Item);

    #[inline]
    fn next(ref self: Zipper<A, B>) -> Option<Self::Item> {
        let a = self.iter.next()?;
        let b = self.other.next()?;
        Option::Some((a, b))
    }
}
