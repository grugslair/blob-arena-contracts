use dojo::event::EventStorage;
use core::poseidon::HashState;
use starknet::{ContractAddress, get_caller_address};
use dojo::{world::WorldStorage, model::ModelStorage};
use blob_arena::{
    lobby::storage::{LobbyStorage, sort_players}, combat::CombatTrait, combatants::CombatantTrait,
    game::GameStorage, achievements::{Achievements, TaskId},
};


#[generate_trait]
impl LobbyImpl of LobbyTrait {
    fn get_sender_combatant(self: @WorldStorage, challenge_id: felt252) -> felt252 {
        let (sender, _) = self.get_game_combatants(challenge_id);
        sender
    }
    fn get_receiver_combatant(self: @WorldStorage, challenge_id: felt252) -> felt252 {
        let (_, receiver) = self.get_game_combatants(challenge_id);
        receiver
    }
    fn assert_caller_sender(self: @WorldStorage, challenge_id: felt252) {
        self.assert_caller_player(self.get_sender_combatant(challenge_id));
    }
    fn get_caller_receiver_from_open_lobby(
        self: @WorldStorage, challenge_id: felt252,
    ) -> ContractAddress {
        let lobby = self.get_lobby(challenge_id);
        self.assert_combat_none(challenge_id);
        assert(lobby.receiver == get_caller_address(), 'Not receiver');
        assert(lobby.open, 'Lobby is closed');
        lobby.receiver
    }
    fn assert_lobby_open(self: @WorldStorage, challenge_id: felt252) {
        self.assert_combat_none(challenge_id);
        assert(self.get_lobby_open(challenge_id), 'Lobby is closed');
    }
    fn assert_caller_can_respond(self: @WorldStorage, challenge_id: felt252) -> felt252 {
        self.assert_lobby_open(challenge_id);
        let (sender_id, receiver_id) = self.get_game_combatants(challenge_id);
        assert(receiver_id.is_non_zero(), 'No response');
        self.assert_caller_player(sender_id);
        sender_id
    }
    fn increase_games_played(
        ref self: WorldStorage, player_1: ContractAddress, player_2: ContractAddress,
    ) {
        let players = sort_players(player_1, player_2);
        let played = self.get_games_played_value(players) + 1;
        if played == 1 {
            self.increment_achievement_now(player_1, TaskId::PvpUniqueOpponent);
            self.increment_achievement_now(player_2, TaskId::PvpUniqueOpponent);
        };
        self.set_games_players(players, self.get_games_played_value(players) + 1);
    }
}

