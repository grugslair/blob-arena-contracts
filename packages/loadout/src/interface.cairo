use starknet::ContractAddress;
use crate::ability::Abilities;
#[starknet::interface]
pub trait ILoadout<TContractState> {
    fn abilities(
        self: @TContractState, collection_address: ContractAddress, token_id: u256,
    ) -> Abilities;
    fn attacks(
        self: @TContractState,
        collection_address: ContractAddress,
        token_id: u256,
        slots: Array<Array<felt252>>,
    ) -> Array<felt252>;
}
