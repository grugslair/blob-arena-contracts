use core::poseidon::HashState;
use starknet::{get_block_timestamp, get_caller_address, ContractAddress};
use dojo::{world::WorldStorage, model::{ModelStorage, Model}, event::EventStorage};
use blob_arena::{
    game::{
        components::{LastTimestamp, Initiator, GameInfo, GameInfoTrait, WinVia, GameProgress},
        storage::GameStorage
    },
    combat::{CombatTrait, Phase, CombatState, CombatStorage, components::PhaseTrait},
    commitments::Commitment, utils::get_transaction_hash,
    combatants::{CombatantTrait, CombatantInfo, CombatantStorage, CombatantState}, salts::Salts,
    hash::in_order, attacks::results::{RoundResult, AttackResult},
    core::{TTupleSized2ToSpan, ArrayTryIntoTTupleSized2}
};


#[generate_trait]
impl GameImpl of GameTrait {
    fn assert_caller_initiator(self: @WorldStorage, game_id: felt252) {
        assert(self.get_initiator(game_id) == get_caller_address(), 'Not the initiator');
    }
    fn assert_contract_is_owner(self: @WorldStorage, game_id: felt252) {
        self.get_game_info(game_id).assert_contract_is_owner();
    }
    fn assert_past_time_limit(self: @WorldStorage, game: GameInfo) {
        assert(game.time_limit.is_non_zero(), 'No time limit set');
        assert(
            get_block_timestamp() - self.get_last_timestamp(game.combat_id) > game.time_limit,
            'Not past time limit'
        );
    }
    fn get_combatants_info_tuple(
        self: @WorldStorage, combatants_info: (felt252, felt252)
    ) -> (CombatantInfo, CombatantInfo) {
        self.get_combatant_infos(combatants_info.span()).try_into().unwrap()
    }
    fn end_game(
        ref self: WorldStorage,
        combat_id: felt252,
        winner: CombatantInfo,
        loser: CombatantInfo,
        via: WinVia
    ) {
        self.set_combat_phase(combat_id, Phase::Ended(winner.id));
        self.emit_combat_end(combat_id, winner, loser, via);
    }
    fn end_game_from_ids(
        ref self: WorldStorage,
        combat_id: felt252,
        winner_id: felt252,
        loser_id: felt252,
        via: WinVia
    ) {
        let (winner, looser) = self.get_combatants_info_tuple((winner_id, loser_id));
        self.end_game(combat_id, winner, looser, via);
    }

    fn _if_winner_end(
        ref self: WorldStorage,
        combat_id: felt252,
        player_1: @CombatantState,
        player_2: @CombatantState
    ) -> bool {
        if (*player_2.health).is_zero() {
            self.end_game_from_ids(combat_id, *player_1.id, *player_2.id, WinVia::Combat);
            true
        } else if (*player_1.health).is_zero() {
            self.end_game_from_ids(combat_id, *player_2.id, *player_1.id, WinVia::Combat);
            true
        } else {
            false
        }
    }

    fn if_winner_end(
        ref self: WorldStorage,
        combat_id: felt252,
        player_1: @CombatantState,
        player_2: @CombatantState
    ) -> GameProgress {
        if (*player_2.health).is_zero() {
            GameProgress::Ended([*player_1.id, *player_2.id])
        } else if (*player_1.health).is_zero() {
            GameProgress::Ended([*player_2.id, *player_1.id])
        } else {
            GameProgress::Active
        }
    }

    fn run_game_round(ref self: WorldStorage, game: GameInfo) {
        let combat = self.get_combat_state(game.combat_id);
        combat.phase.assert_reveal();

        let combatants_span = game.combatant_ids.span();
        assert(self.check_commitments_unset(combatants_span), 'Not all attacks revealed');
        let hash = self.get_salts_hash_state(combat.id);

        let (progress, results) = self.run_round(combat.id, combat.round, combatants_span, hash);
        self.emit_round_result(@combat, results);

        match progress {
            GameProgress::Active => self.next_round(combat, combatants_span),
            GameProgress::Ended([
                winner, looser
            ]) => { self.end_game_from_ids(combat.id, winner, looser, WinVia::Combat); }
        }
    }

    fn run_round(
        ref self: WorldStorage,
        combat_id: felt252,
        round: u32,
        combatants: Span<felt252>,
        hash: HashState,
    ) -> (GameProgress, Array<AttackResult>) {
        let mut array = self.get_states_and_attacks(combatants);
        let ordered = in_order(array.at(0).get_speed(), array.at(1).get_speed(), hash);
        let (a, b) = (array.pop_front().unwrap(), array.pop_front().unwrap());
        let ((mut state_1, attack_1), (mut state_2, attack_2)) = if ordered {
            (a, b)
        } else {
            (b, a)
        };
        let mut results = array![];
        results.append(self.run_attack(ref state_1, ref state_2, attack_1, round, hash));
        let mut progress = self.if_winner_end(combat_id, @state_2, @state_1);
        if progress == GameProgress::Active {
            results.append(self.run_attack(ref state_2, ref state_1, attack_2, round, hash));
            progress = self.if_winner_end(combat_id, @state_1, @state_2)
        };
        self.set_combatant_states([@state_1, @state_2].span());
        (progress, results)
    }
}

