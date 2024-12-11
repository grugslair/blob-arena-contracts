use starknet::ContractAddress;

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
}
