use starknet::ContractAddress;
use crate::action::{Action, ActionWithName, Effect};
use super::IdTagAction;
use super::action::{ChanceEffects, Effects};

#[starknet::interface]
pub trait IAction<TContractState> {
    fn action(self: @TContractState, id: felt252) -> Action;
    fn actions(self: @TContractState, ids: Array<felt252>) -> Array<Action>;
    fn speed(self: @TContractState, id: felt252) -> u16;
    fn speeds(self: @TContractState, ids: Array<felt252>) -> Array<u16>;
    fn cooldown(self: @TContractState, id: felt252) -> u32;
    fn get_effects(self: @TContractState, id: felt252, chance_value: u32) -> (u16, Array<Effect>);
    fn effects(self: @TContractState, id: felt252) -> Effects;
    fn base_effects(self: @TContractState, id: felt252) -> Array<Effect>;
    fn chance_effects(self: @TContractState, id: felt252) -> Array<ChanceEffects>;
    fn action_id(
        self: @TContractState,
        name: ByteArray,
        speed: u16,
        cooldown: u32,
        base_effects: Array<Effect>,
        chance_effects: Array<ChanceEffects>,
    ) -> felt252;
    fn action_ids(self: @TContractState, actions: Array<ActionWithName>) -> Array<felt252>;
    fn check_action(
        self: @TContractState,
        name: ByteArray,
        speed: u16,
        cooldown: u32,
        base_effects: Array<Effect>,
        chance_effects: Array<ChanceEffects>,
    ) -> (felt252, bool);
    fn check_actions(
        self: @TContractState, actions: Array<ActionWithName>,
    ) -> Array<(felt252, bool)>;
    fn check_action_arrays(
        self: @TContractState, actions_arrays: Array<Array<ActionWithName>>,
    ) -> Array<Array<(felt252, bool)>>;
    fn tag(self: @TContractState, tag: felt252) -> felt252;
}


#[starknet::interface]
pub trait IActionAdmin<TContractState> {
    fn create_action(
        ref self: TContractState,
        name: ByteArray,
        speed: u16,
        cooldown: u32,
        base_effects: Array<Effect>,
        chance_effects: Array<ChanceEffects>,
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
