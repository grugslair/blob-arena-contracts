use ba_utils::RandomnessTrait;
use starknet::syscalls::call_contract_syscall;
use starknet::{ContractAddress, SyscallResultTrait};
use crate::Randomness;

#[derive(Drop, Copy, Clone, Serde)]
pub enum Source {
    Nonce: ContractAddress,
    Salt: felt252,
}


pub fn consume_random_salt(contract_address: ContractAddress, salt: felt252) -> felt252 {
    *call_contract_syscall(contract_address, selector!("consume_random"), [1, salt].span())
        .unwrap_syscall()[0]
}

pub fn consume_randomness_salt(contract_address: ContractAddress, salt: felt252) -> Randomness {
    RandomnessTrait::new(consume_random_salt(contract_address, salt))
}

pub fn consume_random_nonce(contract_address: ContractAddress, caller: ContractAddress) -> felt252 {
    *call_contract_syscall(contract_address, selector!("consume_random"), [0, caller.into()].span())
        .unwrap_syscall()[0]
}

pub fn consume_randomness_nonce(
    contract_address: ContractAddress, caller: ContractAddress,
) -> Randomness {
    RandomnessTrait::new(consume_random_nonce(contract_address, caller))
}

#[starknet::interface]
trait IVrfComponent<TState> {
    fn vrf_address(self: @TState) -> ContractAddress;
    fn set_vrf_address(ref self: TState, contract_address: ContractAddress);
}


pub trait VrfTrait<TState, +Drop<TState>> {
    fn get_nonce_seed(ref self: TState, caller: ContractAddress) -> felt252;
    fn get_salt_seed(ref self: TState, salt: felt252) -> felt252;
    fn get_salt_randomness(
        ref self: TState, salt: felt252,
    ) -> Randomness {
        RandomnessTrait::new(Self::get_salt_seed(ref self, salt))
    }
    fn get_nonce_randomness(
        ref self: TState, caller: ContractAddress,
    ) -> Randomness {
        RandomnessTrait::new(Self::get_nonce_seed(ref self, caller))
    }
}

impl VrfContractImpl<
    TState, +vrf_component::HasComponent<TState>, +Drop<TState>,
> of VrfTrait<TState> {
    fn get_salt_seed(ref self: TState, salt: felt252) -> felt252 {
        let mut component = self.get_component_mut();
        vrf_component::VrfComponentImpl::<TState>::get_salt_seed(ref component, salt)
    }

    fn get_nonce_seed(ref self: TState, caller: ContractAddress) -> felt252 {
        let mut component = self.get_component_mut();
        vrf_component::VrfComponentImpl::<TState>::get_nonce_seed(ref component, caller)
    }
}
pub use vrf_component::HasComponent as HasVrfComponent;

#[starknet::component]
pub mod vrf_component {
    use sai_ownable::OwnableTrait;
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use super::{IVrfComponent, VrfTrait, consume_random_nonce, consume_random_salt};

    #[storage]
    pub struct Storage {
        vrf_address: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {}


    #[embeddable_as(VrfImpl)]
    impl IVrfComponentImpl<
        TContractState, +OwnableTrait<TContractState>, +HasComponent<TContractState>,
    > of IVrfComponent<ComponentState<TContractState>> {
        fn vrf_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.vrf_address.read()
        }

        fn set_vrf_address(
            ref self: ComponentState<TContractState>, contract_address: ContractAddress,
        ) {
            self.get_contract().assert_caller_is_owner();
            self.vrf_address.write(contract_address);
        }
    }


    pub impl VrfComponentImpl<TContractState> of VrfTrait<ComponentState<TContractState>> {
        fn get_salt_seed(ref self: ComponentState<TContractState>, salt: felt252) -> felt252 {
            let vrf_address = self.vrf_address.read();
            consume_random_salt(vrf_address, salt)
        }

        fn get_nonce_seed(
            ref self: ComponentState<TContractState>, caller: ContractAddress,
        ) -> felt252 {
            let caller = starknet::get_caller_address();
            let vrf_address = self.vrf_address.read();
            consume_random_nonce(vrf_address, caller)
        }
    }
}


#[starknet::interface]
trait IMockVrf<TState> {
    fn consume_random(ref self: TState, source: Source) -> felt252;
    fn assert_consumed(ref self: TState, seed: felt252);
}


#[starknet::contract]
mod mock_vrf {
    use core::poseidon::poseidon_hash_span;
    use sai_core_utils::poseidon_hash_three;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::{ContractAddress, get_caller_address};
    use super::{IMockVrf, Source};

    #[storage]
    struct Storage {
        consumed: Map<felt252, bool>,
        nonce: Map<ContractAddress, felt252>,
    }

    #[abi(embed_v0)]
    impl IMockVrfImpl of IMockVrf<ContractState> {
        fn consume_random(ref self: ContractState, source: Source) -> felt252 {
            let caller = get_caller_address();
            let chain_id = starknet::get_execution_info().tx_info.unbox().chain_id;
            let seed = match source {
                Source::Nonce(contract_address) => {
                    let nonce = self.nonce.read(caller);
                    self.nonce.write(caller, nonce + 1);
                    poseidon_hash_span(
                        [contract_address.into(), nonce, caller.into(), chain_id].span(),
                    )
                },
                Source::Salt(salt) => poseidon_hash_three(salt, caller, chain_id),
            };
            assert(!self.consumed.read(seed), 'Seed already consumed');
            self.consumed.write(seed, true);
            seed
        }

        fn assert_consumed(ref self: ContractState, seed: felt252) {
            assert(self.consumed.read(seed), 'Seed not consumed');
        }
    }
}

