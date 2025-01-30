use starknet::{ContractAddress, get_contract_address};
use blob_arena::collections::ERC721Token;

#[dojo::model]
#[derive(Drop, Serde, Copy)]
struct GameInfo {
    #[key]
    combat_id: felt252,
    owner: ContractAddress,
    time_limit: u64,
    combatant_ids: (felt252, felt252),
}

#[dojo::model]
#[derive(Drop, Serde, Copy)]
struct Initiator {
    #[key]
    game_id: felt252,
    initiator: ContractAddress,
}

#[dojo::model]
#[derive(Drop, Serde, Copy)]
struct LastTimestamp {
    #[key]
    game_id: felt252,
    timestamp: u64,
}

#[derive(Drop, Serde, Copy, Introspect)]
struct Player {
    player: ContractAddress,
    combatant_id: felt252,
    token: ERC721Token,
}

#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
enum WinVia {
    Combat,
    TimeLimit,
    Forfeit,
    IncorrectReveal,
}

#[dojo::event]
#[derive(Drop, Serde, Copy)]
struct CombatEnd {
    #[key]
    game_id: felt252,
    winner: Player,
    loser: Player,
    via: WinVia,
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

