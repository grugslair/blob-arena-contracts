use ba_loadout::action::IActionDispatcher;
use ba_utils::storage::{read_at_felt252, write_at_felt252};
use starknet::ContractAddress;

const ATTACK_DISPATCHER_STORAGE_ADDRESS: felt252 = selector!("action_dispatcher");

pub fn set_action_dispatcher_address(contract_address: ContractAddress) {
    write_at_felt252(ATTACK_DISPATCHER_STORAGE_ADDRESS, contract_address.into());
}

pub fn get_action_dispatcher() -> IActionDispatcher {
    IActionDispatcher { contract_address: get_action_dispatcher_address() }
}


pub fn get_action_dispatcher_address() -> ContractAddress {
    read_at_felt252(ATTACK_DISPATCHER_STORAGE_ADDRESS).try_into().unwrap()
}
