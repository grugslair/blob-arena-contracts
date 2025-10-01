use ba_loadout::attack::IAttackDispatcher;
use ba_utils::storage::{read_at_felt252, write_at_felt252};
use starknet::ContractAddress;

const ATTACK_DISPATCHER_STORAGE_ADDRESS: felt252 = selector!("attack_dispatcher");

pub fn set_attack_dispatcher_address(contract_address: ContractAddress) {
    write_at_felt252(ATTACK_DISPATCHER_STORAGE_ADDRESS, contract_address.into());
}

pub fn get_attack_dispatcher() -> IAttackDispatcher {
    IAttackDispatcher {
        contract_address: read_at_felt252(ATTACK_DISPATCHER_STORAGE_ADDRESS).try_into().unwrap(),
    }
}
