use sai_core_utils::SerdeAll;
use starknet::syscalls::{call_contract_syscall, library_call_syscall};
use starknet::{ClassHash, ContractAddress, SyscallResultTrait};

pub trait ExternalCalls<Args, Return> {
    fn call_library(self: ClassHash, selector: felt252, args: Args) -> Return;
    fn call_contract(self: ContractAddress, selector: felt252, args: Args) -> Return;
}


pub impl SerdeExternalCalls<
    Args, Return, +Serde<Args>, +Serde<Return>, +Drop<Args>,
> of ExternalCalls<Args, Return> {
    fn call_library(self: ClassHash, selector: felt252, args: Args) -> Return {
        library_call_syscall(self, selector, SerdeAll::serialize_all(@args))
            .unwrap_syscall()
            .deserialize_unwrap_all()
    }

    fn call_contract(self: ContractAddress, selector: felt252, args: Args) -> Return {
        call_contract_syscall(self, selector, SerdeAll::serialize_all(@args))
            .unwrap_syscall()
            .deserialize_unwrap_all()
    }
}
