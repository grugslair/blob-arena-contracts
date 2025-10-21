use starknet::ContractAddress;
use crate::action::{Action, ActionWithName, Effect};
use super::IdTagAction;

#[starknet::interface]
pub trait IAction<TContractState> {
    fn action(self: @TContractState, id: felt252) -> Action;
    fn actions(self: @TContractState, ids: Array<felt252>) -> Array<Action>;
    fn speed(self: @TContractState, id: felt252) -> u16;
    fn speeds(self: @TContractState, ids: Array<felt252>) -> Array<u16>;
    fn cooldown(self: @TContractState, id: felt252) -> u32;
    fn cooldowns(self: @TContractState, ids: Array<felt252>) -> Array<u32>;
    fn effects(self: @TContractState, id: felt252) -> Array<Effect>;
    fn chance(self: @TContractState, id: felt252) -> u8;
    fn chances(self: @TContractState, id: felt252) -> u8;
    fn action_id(
        self: @TContractState,
        name: ByteArray,
        speed: u16,
        chance: u8,
        cooldown: u32,
        success: Array<Effect>,
        fail: Array<Effect>,
    ) -> felt252;
    fn action_ids(self: @TContractState, actions: Array<ActionWithName>) -> Array<felt252>;
    fn tag(self: @TContractState, tag: felt252) -> felt252;
}


#[starknet::interface]
pub trait IActionAdmin<TContractState> {
    fn create_action(
        ref self: TContractState,
        name: ByteArray,
        speed: u16,
        chance: u8,
        cooldown: u32,
        success: Array<Effect>,
        fail: Array<Effect>,
    ) -> felt252;
    fn create_actions(ref self: TContractState, actions: Array<ActionWithName>) -> Array<felt252>;
    fn maybe_create_actions(
        ref self: TContractState, actions: Array<IdTagAction>,
    ) -> Array<felt252>;
    fn maybe_create_actions_array(
        ref self: TContractState, actions: Array<Array<IdTagAction>>,
    ) -> Array<Array<felt252>>;
}

pub fn maybe_create_actions(
    contract_address: ContractAddress, actions: Array<IdTagAction>,
) -> Array<felt252> {
    IActionAdminDispatcher { contract_address }.maybe_create_actions(actions)
}

pub fn maybe_create_actions_array(
    contract_address: ContractAddress, actions: Array<Array<IdTagAction>>,
) -> Array<Array<felt252>> {
    IActionAdminDispatcher { contract_address }.maybe_create_actions_array(actions)
}
