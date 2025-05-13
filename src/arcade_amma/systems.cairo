use core::cmp::min;
use core::dict::Felt252Dict;
use starknet::{ContractAddress, get_block_timestamp, get_caller_address};

use dojo::world::WorldStorage;

use crate::hash::{felt252_to_u128, hash_value};
use crate::utils::SeedProbability;
use crate::arcade::{
    ArcadeStore, ArcadeStorage, ArcadeTrait, ArcadeGame, ArcadePhaseTrait, ArcadePhase,
    calc_restored_health, ARCADE_CHALLENGE_MAX_RESPAWNS,
};
use crate::arcade_amma::{AmmaArcadeStorage, AMMA_ARCADE_GENERATED_STAGES};
use crate::combatants::{CombatantTrait, CombatantStorage};
use crate::stats::{UStats, StatsTrait};
use crate::world::uuid;
use crate::achievements::{Achievements, TaskId};
use crate::collections::amma_blobert::AmmaBlobertStorage;

const HEALTH_RESTORE_PERCENTAGE: u8 = 40;

fn random_selection(seed: felt252, range: u32, number: u32) -> Array<u32> {
    assert(number <= range, 'Number must be <= to range');
    let mut seed = felt252_to_u128(seed);
    let mut values: Array<u32> = Default::default();
    let mut dict: Felt252Dict<u128> = Default::default();
    for n in 0..range {
        dict.insert(n.into(), n.into());
    };
    for i in 0_u128..min(number.into(), range.into() - 1) {
        let j: u128 = (i + seed.get_value((range.into() - i).try_into().unwrap()))
            .try_into()
            .unwrap();
        values.append(dict.get(j.into()).try_into().unwrap());
        dict.insert(j.into(), dict.get(i.into()));
    };
    if range == number {
        values.append(dict.get((range - 1).into()).try_into().unwrap());
    }
    values
}

fn get_stage_stats(stage: u32, fighter_stats: UStats) -> UStats {
    let stage_stats: UStats = (5_u8 * stage.try_into().unwrap() + 5_u8).into();
    stage_stats + fighter_stats
}


#[generate_trait]
impl AmmaArcadeImpl of AmmaArcadeTrait {
    fn new_amma_arcade_challenge_attempt(
        ref self: ArcadeStore,
        seed: felt252,
        player: ContractAddress,
        collection: ContractAddress,
        token_id: u256,
        attacks: Array<(felt252, felt252)>,
        total_fighters: u32,
    ) -> (felt252, felt252) {
        let timestamp = get_block_timestamp();
        self.arcade.use_game(player, timestamp);

        let (stats, attacks) = self.ba.get_token_stats_and_attacks(collection, token_id, attacks);
        let attempt = self
            .arcade
            .new_amma_arcade_challenge_attempt(seed, player, token_id, stats, attacks, timestamp);
        self.arcade.set_arcade_current_challenge_attempt(player, collection, token_id, seed);

        let fighters = random_selection(seed, total_fighters, AMMA_ARCADE_GENERATED_STAGES);
        let r0_fighter = *fighters[0];
        self.arcade.set_amma_round_opponents(attempt.id, fighters);
        let game = self
            .setup_amma_arcade_opponent_in_combat(
                attempt.player,
                attempt.stats,
                stats.get_max_health(),
                attempt.attacks.span(),
                r0_fighter,
                0,
            );

        self.arcade.set_arcade_stage_game(seed, 0, game.id);
        (seed, game.id)
    }

    fn get_amma_stage_stats(self: @WorldStorage, stage: u32, fighter: u32) -> UStats {
        (5_u8 * stage.try_into().unwrap() + 10_u8).into()
            + self.get_amma_fighter_generated_stats(fighter.into())
    }

    fn create_amma_arcade_challenge_attempt_round(
        ref self: ArcadeStore,
        id: felt252,
        player: ContractAddress,
        stats: UStats,
        attacks: Array<felt252>,
        stage: u32,
        health: u8,
    ) -> felt252 {
        let opponent = self.arcade.get_amma_round_opponent(id, stage);
        let game = self
            .setup_amma_arcade_opponent_in_combat(
                player, stats, health, attacks.span(), opponent, stage,
            );
        self.arcade.set_arcade_stage_game(id, stage, game.id);
        game.id
    }

    fn setup_amma_arcade_opponent_in_combat(
        ref self: ArcadeStore,
        player: ContractAddress,
        stats: UStats,
        health: u8,
        attacks: Span<felt252>,
        opponent_token: u32,
        stage: u32,
    ) -> ArcadeGame {
        let game_id = uuid();
        let opponent_id = hash_value(@[game_id, 'opponent']);
        let combatant_id = hash_value(@[game_id, 'combatant']);
        assert(opponent_token > 0, 'Invalid opponent');
        let opponent_stats = if stage < AMMA_ARCADE_GENERATED_STAGES {
            self.arcade.get_amma_stage_stats(stage, opponent_token)
        } else {
            self.arcade.get_amma_fighter_stats(opponent_token.into())
        };
        self.ba.create_combatant_state(opponent_id, opponent_stats);
        self.ba.set_combatant_stats_health_and_attacks(combatant_id, stats, health, attacks);
        self
            .arcade
            .new_arcade_game_model(
                game_id, combatant_id, player, opponent_token.into(), opponent_id,
            )
    }

    fn next_amma_arcade_challenge_round(ref self: ArcadeStore, attempt_id: felt252) -> felt252 {
        let mut attempt = self.arcade.get_amma_arcade_challenge_attempt_next_stage(attempt_id);
        assert(attempt.player == get_caller_address(), 'Not player');
        attempt.phase.assert_active();
        let (combatant_id, phase) = self
            .arcade
            .get_arcade_game_combatant_phase(
                self.arcade.get_arcade_stage_game_id(attempt_id, attempt.stage),
            );
        assert(phase == ArcadePhase::PlayerWon, 'Player not won last round');
        assert(get_block_timestamp() <= attempt.expiry, 'Challenge expired');
        assert(attempt.stage <= AMMA_ARCADE_GENERATED_STAGES, 'No more stages');
        let health = calc_restored_health(
            self.ba.get_combatant_health(combatant_id),
            attempt.stats.vitality,
            HEALTH_RESTORE_PERCENTAGE,
        );

        attempt.stage += 1;

        self.arcade.set_arcade_challenge_stage(attempt_id, attempt.stage);

        self
            .create_amma_arcade_challenge_attempt_round(
                attempt_id, attempt.player, attempt.stats, attempt.attacks, attempt.stage, health,
            )
    }

    fn respawn_amma_arcade_challenge_attempt(
        ref self: ArcadeStore, attempt_id: felt252,
    ) -> felt252 {
        let mut attempt = self.arcade.get_amma_arcade_challenge_attempt_respawn(attempt_id);
        let game_id = self.arcade.get_arcade_stage_game_id(attempt_id, attempt.stage);
        let phase = self.arcade.get_arcade_game_phase(game_id);
        let timestamp = get_block_timestamp();

        attempt.phase.assert_active();
        assert(attempt.player == get_caller_address(), 'Not player');
        assert(timestamp <= attempt.expiry, 'Challenge expired');
        assert(phase == ArcadePhase::PlayerLost, 'Player not lost round');
        assert(attempt.respawns < ARCADE_CHALLENGE_MAX_RESPAWNS, 'Max respawns');
        self.arcade.use_game(attempt.player, timestamp);

        attempt.respawns += 1;

        self.arcade.set_arcade_challenge_respawns(attempt_id, attempt.respawns);
        self.arcade.emit_arcade_respawn(attempt_id, attempt.respawns, attempt.stage, game_id);
        let health = attempt.stats.get_max_health();
        self
            .create_amma_arcade_challenge_attempt_round(
                attempt_id, attempt.player, attempt.stats, attempt.attacks, attempt.stage, health,
            )
    }

    fn end_amma_arcade_challenge_attempt(
        ref self: WorldStorage, collection_address: ContractAddress, attempt_id: felt252,
    ) {
        let attempt = self.get_amma_arcade_challenge_attempt_end(attempt_id);
        assert(attempt.player == get_caller_address(), 'Not player');
        attempt.phase.assert_active();
        let game_id = self.get_arcade_stage_game_id(attempt_id, attempt.stage);
        let won = match self.get_arcade_game_phase(game_id) {
            ArcadePhase::PlayerWon => { AMMA_ARCADE_GENERATED_STAGES >= attempt.stage },
            ArcadePhase::PlayerLost => false,
            ArcadePhase::Active => {
                self.set_arcade_ended(game_id, false);
                false
            },
            _ => panic!("Combat not started"),
        };
        self
            .remove_arcade_current_challenge_attempt(
                attempt.player, collection_address, attempt.token_id,
            );
        self.set_arcade_challenge_attempt_ended(attempt_id, won);
        if won {
            let timestamp = get_block_timestamp();
            self.increment_achievement(attempt.player, TaskId::AmmaArcadeCompletion, timestamp);
            if attempt.respawns.is_zero() {
                self
                    .increment_achievement(
                        attempt.player, TaskId::ArcadeCompletionNoRespawn, timestamp,
                    );
            }
        }
    }
}

