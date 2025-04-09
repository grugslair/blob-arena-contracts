use starknet::{ContractAddress, get_contract_address};
use crate::erc721::ERC721Token;
/// Game Models

/// Represents game information for a combat encounter
/// # Arguments
/// * `combat_id` - Unique identifier for the combat instance, used as a key
/// * `owner` - Contract address of the game owner/creator
/// * `time_limit` - Maximum duration of inactivity for the combat in seconds
/// * `combatant_ids` - Tuple containing the two combatant IDs participating in the combat

#[dojo::model]
#[derive(Drop, Serde, Copy)]
struct GameInfo {
    #[key]
    combat_id: felt252,
    owner: ContractAddress,
    time_limit: u64,
    combatant_ids: (felt252, felt252),
}

/// Represents the initiator of a game session.
///
/// # Arguments
///
/// * `game_id` - Unique identifier for the game session (key field)
/// * `initiator` - Contract address of the account that can initiate the game
#[dojo::model]
#[derive(Drop, Serde, Copy)]
struct Initiator {
    #[key]
    game_id: felt252,
    initiator: ContractAddress,
}

/// Component to store the latest timestamp for a game
///
/// # Arguments
///
/// * `game_id` - The unique identifier for the game
/// * `timestamp` - The latest timestamp recorded for this game (in seconds)
#[dojo::model]
#[derive(Drop, Serde, Copy)]
struct LastTimestamp {
    #[key]
    game_id: felt252,
    timestamp: u64,
}

/// Event emitted when a combat instance ends
///
/// # Arguments
/// * `game_id` - The unique identifier of the game instance
/// * `winner` - The player who won the combat
/// * `loser` - The player who lost the combat
/// * `via` - The method by which the winner achieved victory
#[dojo::event]
#[derive(Drop, Serde)]
struct CombatEnd {
    #[key]
    game_id: felt252,
    winner: Player,
    loser: Player,
    via: WinVia,
}

/// Tracks the number of games completed between two players
///
/// # Fields
/// * `players` - A tuple of player contract addresses who played against each other in acending
/// * `completed` - The total number of games completed between these players
#[dojo::model]
#[derive(Drop, Serde)]
struct GamesCompleted {
    #[key]
    players: (ContractAddress, ContractAddress),
    completed: u64,
}


#[derive(Drop, Serde, Copy, Introspect)]
struct Player {
    player: ContractAddress,
    combatant_id: felt252,
    token: ERC721Token,
}

/// The way a game concluded with a winner.
///
/// # Variants
/// * `Combat` - Winner eliminated opponent through battle
/// * `TimeLimit` - The looser was inactive for longer than the time limit
/// * `Forfeit` - Winner's opponent forfeited the match
/// * `IncorrectReveal` - Winner's opponent provided incorrect commitment reveal

#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
enum WinVia {
    Combat,
    TimeLimit,
    Forfeit,
    IncorrectReveal,
}


#[derive(Copy, Drop, Serde, PartialEq)]
enum GameProgress {
    Active,
    Ended: [felt252; 2],
}

#[generate_trait]
impl GameInfoImpl of GameInfoTrait {
    fn get_opponent_id(self: @GameInfo, combatant_id: felt252) -> felt252 {
        let (a, b) = *self.combatant_ids;
        if combatant_id == a {
            b
        } else if combatant_id == b {
            a
        } else {
            panic!("Combatant not in combat")
        }
    }

    fn assert_contract_is_owner(self: @GameInfo) {
        assert(*self.owner == get_contract_address(), 'Not the contract owner');
    }
}

