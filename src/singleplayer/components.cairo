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
fn attack(game_id: felt252, attack_id: felt252) {
    // TODO: implement attack logic, sender 

    let game = self.get_storage().get_component::<SingleplayerGame>(game_id);
    assert(game.player == get_caller_address(), 'Not the player');

    let blobert = self.get_storage().get_component::<SingleplayerBlobert>(game.player_id);
    let attack = blobert.attacks[attack_id];

    // TODO: implement attack logic
}
