use starknet::ContractAddress;
use blob_arena::stats::UStats;

#[starknet::interface]
trait ICollection<TContractState> {
    fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress;
    fn get_approved(self: @TContractState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(
        self: @TContractState, owner: ContractAddress, operator: ContractAddress
    ) -> bool;
    fn get_stats(self: @TContractState, token_id: u256) -> UStats;
    fn get_attack_slot(
        self: @TContractState, token_id: u256, item_id: felt252, slot: felt252
    ) -> felt252;
    fn get_attack_slots(
        self: @TContractState, token_id: u256, item_slots: Array<(felt252, felt252)>
    ) -> Array<felt252>;
}

fn get_collection_dispatcher(contract_address: ContractAddress) -> ICollectionDispatcher {
    ICollectionDispatcher { contract_address }
}

