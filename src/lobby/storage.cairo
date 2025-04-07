use starknet::ContractAddress;
use dojo::{
    world::WorldStorage, model::{ModelStorage, Model, ModelValueStorage}, event::EventStorage,
};
use blob_arena::lobby::components::{Lobby, LobbyValue, LobbyCreated, GamesPlayed};

fn sort_players(
    player_1: ContractAddress, player_2: ContractAddress,
) -> (ContractAddress, ContractAddress) {
    match player_1 < player_2 {
        true => (player_1, player_2),
        false => (player_2, player_1),
    }
}

#[generate_trait]
impl LobbyStorageImpl of LobbyStorage {
    fn create_lobby(ref self: WorldStorage, id: felt252, receiver: ContractAddress) {
        // self.write_model(@Lobby { id, open: true, responded: false });
        self.write_model(@Lobby { id, receiver, open: true });
    }
    fn get_lobby(self: @WorldStorage, id: felt252) -> LobbyValue {
        self.read_value(id)
    }
    fn get_lobby_open(self: @WorldStorage, id: felt252) -> bool {
        self.read_member(Model::<Lobby>::ptr_from_keys(id), selector!("open"))
    }
    fn close_lobby(ref self: WorldStorage, id: felt252) {
        self.write_member(Model::<Lobby>::ptr_from_keys(id), selector!("open"), false);
    }
    fn emit_lobby_created(
        ref self: WorldStorage, id: felt252, sender: ContractAddress, receiver: ContractAddress,
    ) {
        self.emit_event(@LobbyCreated { id, sender, receiver });
    }

    fn get_games_played(
        self: @WorldStorage, player_1: ContractAddress, player_2: ContractAddress,
    ) -> u64 {
        self
            .read_member(
                Model::<GamesPlayed>::ptr_from_keys(sort_players(player_1, player_2)),
                selector!("played"),
            )
    }

    fn get_games_played_value(
        self: @WorldStorage, players: (ContractAddress, ContractAddress),
    ) -> u64 {
        self.read_member(Model::<GamesPlayed>::ptr_from_keys(players), selector!("played"))
    }

    fn set_games_players(
        ref self: WorldStorage, players: (ContractAddress, ContractAddress), played: u64,
    ) {
        self.write_model(@GamesPlayed { players, played });
    }
    // fn set_lobby_response(ref self: WorldStorage, id: felt252, response: bool) {
//     self.write_member(Model::<Lobby>::ptr_from_keys(id), selector!("responded"), response);
// }
}
