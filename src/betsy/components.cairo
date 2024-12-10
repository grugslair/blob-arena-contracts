use starknet::ContractAddress;
use blob_arena::{
    storage::{read_value_from_felt252, write_value_from_felt252}, game::contract::IGameDispatcher
};

const GAME_CONTRACT_ADDRESS_SELECTOR: felt252 = 'game.contract_address';

#[dojo::model]
#[derive(Drop, Serde, Copy)]
struct Winner {
    #[key]
    game_id: felt252,
    winner: ContractAddress,
}

#[dojo::model]
#[derive(Drop, Serde, Copy)]
struct Player {
    #[key]
    combatant_id: felt252,
    contract_address: ContractAddress,
}

#[dojo::model]
#[derive(Drop, Serde, Copy)]
struct TimeLimit {
    #[key]
    game_id: felt252,
    time_limit: u64,
}

#[dojo::model]
#[derive(Drop, Serde, Copy)]
struct LastTimestamp {
    #[key]
    game_id: felt252,
    timestamp: u64,
}

// #[dojo::model]
// #[derive(Drop, Serde, Copy)]
// struct Owner {
//     #[key]
//     game_id: felt252,
//     owner: ContractAddress,
// }

// #[dojo::model]
// #[derive(Drop, Serde, Copy)]
// struct Started {
//     #[key]
//     game_id: felt252,
//     started: bool,
// }

fn get_game_contract_address() -> ContractAddress {
    read_value_from_felt252(GAME_CONTRACT_ADDRESS_SELECTOR)
}

fn set_game_contract_address(contract_address: ContractAddress) {
    write_value_from_felt252(GAME_CONTRACT_ADDRESS_SELECTOR, contract_address)
}

fn game_dispatcher() -> IGameDispatcher {
    IGameDispatcher { contract_address: get_game_contract_address() }
}
