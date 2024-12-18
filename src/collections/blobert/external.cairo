use starknet::{ContractAddress, class_hash::class_hash_const, contract_address_const};
use super::TokenAttributes;


const BLOBERT_CONTRACT_ADDRESS: felt252 =
    0x032cb9f30629268612ffb6060e40dfc669849c7d72539dd23c80fe6578d0549d;


#[starknet::interface]
trait IBlobert<TContractState> {
    // contract state read
    fn traits(self: @TContractState, token_id: u256) -> TokenAttributes;
    fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress;
    fn get_approved(self: @TContractState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(
        self: @TContractState, owner: ContractAddress, operator: ContractAddress
    ) -> bool;
}

fn get_blobert_dispatcher() -> IBlobertDispatcher {
    IBlobertDispatcher { contract_address: contract_address_const::<BLOBERT_CONTRACT_ADDRESS>() }
}
