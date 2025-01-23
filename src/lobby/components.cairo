use starknet::{ContractAddress, get_caller_address, get_block_number};

#[dojo::model]
#[derive(Copy, Drop, Serde)]
struct Lobby {
    #[key]
    id: felt252,
    receiver: ContractAddress,
    open: bool,
}


#[dojo::event]
#[derive(Drop, Serde)]
struct LobbyCreated {
    #[key]
    id: felt252,
    sender: ContractAddress,
    receiver: ContractAddress,
}
