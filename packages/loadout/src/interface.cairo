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
    fn loadout(
        self: @TContractState,
        collection_address: ContractAddress,
        token_id: u256,
        slots: Array<Array<felt252>>,
    ) -> (Abilities, Array<felt252>);
}


pub fn get_loadout(
    contract_address: ContractAddress,
    collection_address: ContractAddress,
    token_id: u256,
    slots: Array<Array<felt252>>,
) -> (Abilities, Array<felt252>) {
    ILoadoutDispatcher { contract_address }.loadout(collection_address, token_id, slots)
}

pub fn get_attacks(
    contract_address: ContractAddress,
    collection_address: ContractAddress,
    token_id: u256,
    slots: Array<Array<felt252>>,
) -> Array<felt252> {
    ILoadoutDispatcher { contract_address }.attacks(collection_address, token_id, slots)
}

pub fn get_abilities(
    contract_address: ContractAddress, collection_address: ContractAddress, token_id: u256,
) -> Abilities {
    ILoadoutDispatcher { contract_address }.abilities(collection_address, token_id)
}
