use core::poseidon::HashState;
use starknet::{get_block_timestamp, get_caller_address, ContractAddress};
use dojo::{world::WorldStorage, model::{ModelStorage, Model}, event::EventStorage};

use crate::game::{
    components::{LastTimestamp, Initiator, GameInfo, GameInfoTrait, WinVia, GameProgress},
    storage::{GameStorage, sort_players},
};
use crate::erc721::ERC721Token;
use crate::combat::{CombatTrait, Phase, CombatState, CombatStorage, components::PhaseTrait};
use crate::commitments::Commitment;
use crate::utils::get_transaction_hash;
use crate::combatants::{CombatantTrait, CombatantInfo, CombatantStorage, CombatantState};
use crate::hash::{in_order, array_to_hash_state};
use crate::attacks::{
    results::{RoundResult, AttackResult, AttackOutcomes, AttackResultTrait}, Attack, AttackStorage,
};
use crate::core::{
    TTupleSized2ToSpan, ArrayTryIntoTTupleSized2, ArrayTryIntoFixed2Array, TTupleSized2IntoFixed,
    BoolIntoOneZero,
};
use crate::attacks::AttackTrait;
use crate::achievements::{Achievements, TaskId};


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
            'Not past time limit',
        );
    }
    fn get_combatants_info_tuple(
        self: @WorldStorage, combatants_info: (felt252, felt252),
    ) -> (CombatantInfo, CombatantInfo) {
        self.get_combatant_infos(combatants_info.span()).try_into().unwrap()
    }
    fn end_game(
        ref self: WorldStorage,
        combat_id: felt252,
        winner: CombatantInfo,
        loser: CombatantInfo,
        timestamp: u64,
        via: WinVia,
    ) {
        self.set_combat_phase(combat_id, Phase::Ended(winner.id));
        if via == WinVia::Combat {
            self.increment_achievement(winner.player, TaskId::PvpBattleVictories, timestamp);
            if self.increase_games_completed(winner.player, loser.player).is_zero() {
                self.increment_achievement(winner.player, TaskId::PvpUniqueOpponent, timestamp);
                self.increment_achievement(loser.player, TaskId::PvpUniqueOpponent, timestamp);
            }
        }
        self.emit_combat_end(combat_id, winner, loser, via);
    }

    fn end_game_from_ids(
        ref self: WorldStorage,
        combat_id: felt252,
        winner_id: felt252,
        loser_id: felt252,
        timestamp: u64,
        via: WinVia,
    ) {
        let (winner, looser) = self.get_combatants_info_tuple((winner_id, loser_id));
        self.end_game(combat_id, winner, looser, timestamp, via);
    }

    fn if_winner_end(
        ref self: WorldStorage,
        combat_id: felt252,
        player_1: @CombatantState,
        player_2: @CombatantState,
    ) -> GameProgress {
        if (*player_2.health).is_zero() {
            GameProgress::Ended([*player_1.id, *player_2.id])
        } else if (*player_1.health).is_zero() {
            GameProgress::Ended([*player_2.id, *player_1.id])
        } else {
            GameProgress::Active
        }
    }

    fn get_attack_order(
        self: @WorldStorage,
        combatants: @[CombatantState; 2],
        attack_ids: [felt252; 2],
        hash: HashState,
    ) -> bool {
        let [attack_1, attack_2] = attack_ids;
        if attack_1.is_zero() {
            return false;
        };
        if attack_2.is_zero() {
            return true;
        };
        let [combatant_1, combatant_2] = combatants;
        let [speed_1, speed_2]: [u8; 2] = self
            .get_attack_speeds(attack_ids.span())
            .try_into()
            .unwrap();
        in_order(
            *combatant_1.stats.dexterity + speed_1, *combatant_2.stats.dexterity + speed_2, hash,
        )
    }

    fn run_game_round(ref self: WorldStorage, game: GameInfo) {
        let combat = self.get_combat_state(game.combat_id);
        combat.phase.assert_reveal();
        let timestamp = get_block_timestamp();

        let combatants_span = game.combatant_ids.span();
        assert(self.check_commitments_unset(combatants_span), 'Not all attacks revealed');

        let combatants = game.combatant_ids.into();
        let (attacks, salts) = self.get_attack_ids_from_combatant_ids(combatants_span);
        let hash = array_to_hash_state(salts);
        let (progress, results) = self
            .run_round(
                combat.id,
                combat.round,
                combatants,
                attacks.try_into().unwrap(),
                [false, false],
                hash,
            );

        match progress {
            GameProgress::Active => self.next_round(combat, combatants_span),
            GameProgress::Ended([
                winner, looser,
            ]) => { self.end_game_from_ids(combat.id, winner, looser, timestamp, WinVia::Combat); },
        };
        for result in results {
            let player = self.get_player(result.combatant_id);
            let new_attack_uses: u32 = self
                .increment_attack_uses(player, result.attack)
                .is_zero()
                .into();
            let (_, opponent) = result.effects();

            self
                .progress_achievements_now(
                    player,
                    array![
                        (TaskId::PvpUniqueMoves, new_attack_uses),
                        (TaskId::CriticalHits, opponent.criticals),
                    ],
                );
        }
    }

    fn run_round(
        ref self: WorldStorage,
        combat_id: felt252,
        round: u32,
        combatants_ids: [felt252; 2],
        attacks: [felt252; 2],
        verified: [bool; 2],
        hash: HashState,
    ) -> (GameProgress, Array<AttackResult>) {
        let combatants = self.get_combatant_states(combatants_ids.span()).try_into().unwrap();
        // This needs to be another line beca compiler bs
        let [ca, cb]: [CombatantState; 2] = combatants;
        let ([aa, ab], [va, vb]) = (attacks, verified);
        let (mut state_1, mut state_2, attack_1, attack_2, verified_1, verified_2) =
            match self.get_attack_order(@combatants, attacks, hash) {
            true => (ca, cb, aa, ab, va, vb),
            false => (cb, ca, ab, aa, vb, va),
        };
        let mut results = array![];
        results
            .append(self.run_attack(ref state_1, ref state_2, attack_1, round, verified_1, hash));
        let mut progress = self.if_winner_end(combat_id, @state_2, @state_1);
        if progress == GameProgress::Active {
            results
                .append(
                    self.run_attack(ref state_2, ref state_1, attack_2, round, verified_2, hash),
                );
            progress = self.if_winner_end(combat_id, @state_1, @state_2)
        };
        self.set_combatant_states([@state_1, @state_2].span());
        self.emit_round_result(combat_id, round, results.span());
        (progress, results)
    }

    fn increase_games_completed(
        ref self: WorldStorage, player_1: ContractAddress, player_2: ContractAddress,
    ) -> u64 {
        let players = sort_players(player_1, player_2);
        let value = self.get_games_completed_value(players);
        self.set_games_completed(players, value + 1);
        value
    }
}

