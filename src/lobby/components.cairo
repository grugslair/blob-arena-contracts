use starknet::{ContractAddress, get_caller_address, get_block_number};

/// Game Models

/// Represents a game lobby in the system
/// # Members
/// * `id` - Unique identifier for the lobby
/// * `receiver` - Contract address of the lobby receiver
/// * `open` - Boolean flag indicating if the lobby is open
#[dojo::model]
#[derive(Copy, Drop, Serde)]
struct Lobby {
    #[key]
    id: felt252,
    receiver: ContractAddress,
    open: bool,
}


/// An event that is emitted when a new lobby is created.
/// # Arguments
/// * `id` - The unique identifier of the lobby (key field)
/// * `sender` - The address of the account that created the lobby
/// * `receiver` - The address of the account that was invited to the lobby
#[dojo::event]
#[derive(Drop, Serde)]
struct LobbyCreated {
    #[key]
    id: felt252,
    sender: ContractAddress,
    receiver: ContractAddress,
}

#[dojo::model]
#[derive(Drop, Serde)]
struct GamesPlayed {
    #[key]
    players: (ContractAddress, ContractAddress),
    played: u64,
}
