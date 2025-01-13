use starknet::ContractAddress;
use dojo::{world::WorldStorage, model::{ModelStorage, Model}};
use blob_arena::stats::UStats;

#[derive(Drop, Serde, Copy, Introspect, PartialEq)]
enum PVEPhase {
    None,
    Active,
    Ended: bool,
}

#[dojo::model]
#[derive(Drop, Serde, Copy)]
struct PVEState {
    id: felt252,
    round: u32,
    phase: PVEPhase,
}

#[dojo::model]
#[derive(Drop, Serde)]
struct PVEToken {
    #[key]
    id: felt252,
    stats: UStats,
    attacks: Array<felt252>,
    available: bool,
}

#[dojo::event]
#[derive(Drop, Serde)]
struct PVEBlobertInfo {
    #[key]
    id: felt252,
    name: ByteArray,
}

#[dojo::model]
#[derive(Drop, Serde, Copy)]
struct PVEGame {
    #[key]
    id: felt252,
    player: ContractAddress,
    player_id: felt252,
    opponent_token: felt252,
    opponent_id: felt252,
    round: u32,
}


#[generate_trait]
impl PVEStorageImpl of PVEStorage {
    fn get_pve_token(self: @WorldStorage, token_id: felt252) -> PVEToken {
        self.read_model(token_id)
    }
    fn set_pve_game(
        ref self: WorldStorage,
        game_id: felt252,
        player: ContractAddress,
        player_id: felt252,
        opponent_token: felt252,
        opponent_id: felt252,
    ) {
        self.write_model(@PVEGame { id: game_id, player, player_id, opponent_token, opponent_id, });
    }

    fn new_pve_state(ref self: WorldStorage, id: felt252) {
        self.write_model(@PVEState { id, round: 1, phase: PVEPhase::Active });
    }

    fn get_pve_state(self: @WorldStorage, id: felt252) -> PVEState {
        self.read_model(id)
    }

    fn set_pve_round(ref self: WorldStorage, id: felt252, round: u32) {
        self.write_member(Model::<PVEState>::ptr_from_keys(id), selector!("round"), round);
    }

    fn set_pve_ended(ref self: WorldStorage, id: felt252, win: bool) {
        self
            .write_member(
                Model::<PVEState>::ptr_from_keys(id), selector!("phase"), PVEPhase::Ended(win)
            );
    }
}
