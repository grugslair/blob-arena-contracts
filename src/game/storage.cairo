use dojo::event::EventStorage;
use starknet::{get_block_timestamp, get_caller_address, ContractAddress};
use dojo::{world::WorldStorage, model::{ModelStorage, Model}};
use blob_arena::{
    game::components::{
        GameInfo, Initiator, LastTimestamp, Player, Token, WinVia, CombatEnd, GameInfoTrait
    },
    combat::{CombatState, Phase, CombatTrait, CombatStorage}, commitments::Commitment,
    combatants::{CombatantStorage, CombatantInfo}
};

#[generate_trait]
impl GameStorageImpl of GameStorage {
    fn get_initiator(self: @WorldStorage, game_id: felt252) -> ContractAddress {
        self.read_member(Model::<Initiator>::ptr_from_keys(game_id), selector!("initiator"))
    }

    fn set_initiator(ref self: WorldStorage, game_id: felt252, initiator: ContractAddress) {
        self.write_model(@Initiator { game_id, initiator });
    }

    fn get_last_timestamp(self: @WorldStorage, game_id: felt252) -> u64 {
        self.read_member(Model::<LastTimestamp>::ptr_from_keys(game_id), selector!("timestamp"))
    }

    fn set_last_timestamp(ref self: WorldStorage, game_id: felt252) {
        self.write_model(@LastTimestamp { game_id, timestamp: get_block_timestamp() });
    }

    fn get_game_info(self: @WorldStorage, game_id: felt252) -> GameInfo {
        self.read_model(game_id)
    }

    fn get_game_combatants(self: @WorldStorage, game_id: felt252) -> (felt252, felt252) {
        self.read_member(Model::<GameInfo>::ptr_from_keys(game_id), selector!("combatant_ids"))
    }

    fn set_game_combatants(
        ref self: WorldStorage, game_id: felt252, combatant_a: felt252, combatant_b: felt252
    ) {
        self
            .write_member(
                Model::<GameInfo>::ptr_from_keys(game_id),
                selector!("combatant_ids"),
                (combatant_a, combatant_b)
            );
    }

    fn set_game_info(
        ref self: WorldStorage,
        game_id: felt252,
        owner: ContractAddress,
        time_limit: u64,
        combatant_a: felt252,
        combatant_b: felt252
    ) {
        self
            .write_model(
                @GameInfo {
                    combat_id: game_id, owner, time_limit, combatant_ids: (combatant_a, combatant_b)
                }
            );
    }

    fn get_winning_player(self: @WorldStorage, game_id: felt252) -> ContractAddress {
        self.get_player(self.get_combat_winner(game_id))
    }

    fn get_combatants_state(
        self: @WorldStorage, combat_id: felt252, combatant_a_id: felt252, combatant_b_id: felt252
    ) -> (bool, bool) {
        match self.get_combat_phase(combat_id) {
            Phase::Commit => (
                self.check_commitment_set(combatant_a_id), self.check_commitment_set(combatant_b_id)
            ),
            Phase::Reveal => (
                self.check_commitment_unset(combatant_a_id),
                self.check_commitment_unset(combatant_b_id)
            ),
            _ => panic!("Not in play phase")
        }
    }

    fn get_end_player(self: @WorldStorage, combatant: CombatantInfo) -> Player {
        let token = self.get_combatant_token_value(combatant.id);
        Player {
            combatant_id: combatant.id,
            player: combatant.player,
            token: Token { collection_address: token.collection_address, token_id: token.token_id, }
        }
    }

    fn get_owners_game(
        self: @WorldStorage, combat_id: felt252, caller: ContractAddress
    ) -> GameInfo {
        let combat = self.get_game_info(combat_id);
        assert(combat.owner == caller, 'Not the owner');
        combat
    }

    fn emit_combat_end(
        ref self: WorldStorage,
        game_id: felt252,
        winner: CombatantInfo,
        loser: CombatantInfo,
        via: WinVia
    ) {
        self
            .emit_event(
                @CombatEnd {
                    game_id,
                    winner: self.get_end_player(winner),
                    loser: self.get_end_player(loser),
                    via
                }
            );
    }

    fn get_opponent(self: @WorldStorage, game: GameInfo, combatant_id: felt252) -> CombatantInfo {
        self.get_combatant_info(game.get_opponent_id(combatant_id))
    }
}
