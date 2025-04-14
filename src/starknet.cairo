use starknet::SyscallResultTrait;
use starknet::{emit_event_syscall, get_contract_address};

const RETURN_KEY_ARRAY: [felt252; 1] = [selector!("__RETURN__")];

fn return_value<T, +Serde<T>, +Drop<T>>(value: T) -> T {
    emit_return(@value);
    value
}

fn emit_return<T, +Serde<T>>(value: @T) {
    let mut serialised = ArrayTrait::<felt252>::new();
    Serde::serialize(value, ref serialised);
    emit_event_syscall(RETURN_KEY_ARRAY.span(), serialised.span()).unwrap_syscall();
}
