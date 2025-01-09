struct BlobertAttacks {
    #[key]
    blobert_id: felt252,
    attacks: Array<felt252>,
}

struct SingleplayerBlobert {
    #[key]
    id: felt252,
    stats: Stats,
    health: u8,
    attacks: Array<felt252>,
}

struct SingleplayerBlobertInfo {
    #[key]
    id: felt252,
    name: felt252,
}

struct SingleplayerGame {
    #[key]
    game_id: felt252,
    player: ContractAddress,
    player_id: felt252,
    // opponent is onchain enemy
    opponent_token_id: felt252,
    opponent_id: felt252,
}

#[dojo::contract]
fn attack()