use starknet::{ContractAddress, class_hash::class_hash_const, contract_address_const};
use super::TokenAttributes;


const BLOBERT_CONTRACT_ADDRESS: felt252 =
    0x00539f522b29ae9251dbf7443c7a950cf260372e69efab3710a11bf17a9599f1;


#[starknet::interface]
trait IBlobert<TContractState> {
    // contract state read
    fn traits(self: @TContractState, token_id: u256) -> TokenAttributes;
    fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress;
    fn get_approved(self: @TContractState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(
        self: @TContractState, owner: ContractAddress, operator: ContractAddress,
    ) -> bool;
}

fn get_blobert_dispatcher() -> IBlobertDispatcher {
    IBlobertDispatcher { contract_address: contract_address_const::<BLOBERT_CONTRACT_ADDRESS>() }
}
