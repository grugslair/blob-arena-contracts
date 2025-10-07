use sai_packing::{GetShift, MaskDowncast};

pub trait GetBytes<T, S> {
    fn get_bytes(value: T, bytes: u8) -> S;
}


impl GetBytesImpl<T, S, +Drop<T>, +Div<T>, +GetShift<T>, +MaskDowncast<T, S>> of GetBytes<T, S> {
    fn get_bytes(value: T, bytes: u8) -> S {
        MaskDowncast::cast(value / GetShift::<T>::get_shift(bytes))
    }
}

