use sai_core_utils::poseidon_hash_two;
use starknet::syscalls::call_contract_syscall;
use starknet::{ContractAddress, SyscallResultTrait, get_contract_address};

#[derive(Drop, Copy, Clone, Serde)]
pub enum Source {
    Nonce: ContractAddress,
    Salt: felt252,
}


// fn consume_random(contract_address: ContractAddress, salt: felt252) -> felt252 {
//     *call_contract_syscall(contract_address, selector!("consume_random"), [1, salt].span())
//         .unwrap_syscall()[0]
// }

pub fn consume_random(contract_address: ContractAddress, salt: felt252) -> felt252 {
    poseidon_hash_two(get_contract_address(), salt)
}


#[starknet::interface]
trait IMockVrf<TState> {
    fn consume_random(ref self: TState, source: Source) -> felt252;
    fn assert_consumed(ref self: TState, seed: felt252);
}
#[starknet::contract]
mod mock_vrf {
    use core::poseidon::poseidon_hash_span;
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
                Source::Salt(salt) => {
                    poseidon_hash_span([salt, caller.into(), chain_id].span())
                },
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

