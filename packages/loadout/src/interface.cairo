use starknet::ContractAddress;
use crate::attributes::Attributes;
#[starknet::interface]
pub trait ILoadout<TContractState> {
    fn attributes(
        self: @TContractState, collection_address: ContractAddress, token_id: u256,
    ) -> Attributes;
    fn actions(
        self: @TContractState,
        collection_address: ContractAddress,
        token_id: u256,
        slots: Array<Array<felt252>>,
    ) -> Array<felt252>;
    fn loadout(
        self: @TContractState,
        collection_address: ContractAddress,
        token_id: u256,
        slots: Array<Array<felt252>>,
    ) -> (Attributes, Array<felt252>);
}


pub fn get_loadout(
    contract_address: ContractAddress,
    collection_address: ContractAddress,
    token_id: u256,
    slots: Array<Array<felt252>>,
) -> (Attributes, Array<felt252>) {
    ILoadoutDispatcher { contract_address }.loadout(collection_address, token_id, slots)
}

pub fn get_actions(
    contract_address: ContractAddress,
    collection_address: ContractAddress,
    token_id: u256,
    slots: Array<Array<felt252>>,
) -> Array<felt252> {
    ILoadoutDispatcher { contract_address }.actions(collection_address, token_id, slots)
}

pub fn get_attributes(
    contract_address: ContractAddress, collection_address: ContractAddress, token_id: u256,
) -> Attributes {
    ILoadoutDispatcher { contract_address }.attributes(collection_address, token_id)
}
