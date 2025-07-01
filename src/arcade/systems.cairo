use core::{cmp::min, poseidon::poseidon_hash_span, num::traits::WideMul};

use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_timestamp};

use dojo::world::WorldStorage;


use crate::attacks::{Attack, AttackInput, AttackTrait, results::AttackResultTrait};
use crate::arcade::{
    ArcadeGame, ArcadeOpponent, ArcadeOpponentInput, ArcadeBlobertInfo, ArcadeStorage, ArcadePhase,
    ArcadeStore, ArcadeChallengeAttempt, ArcadePhaseTrait, ArcadeAttemptEnd,
    components::{
        OPPONENT_TAG_GROUP, CHALLENGE_TAG_GROUP, ARCADE_CHALLENGE_MAX_RESPAWNS,
        ArcadeAttemptRespawn, ArcadeAttemptGetGame, ARCADE_CHALLENGE_GAME_ENERGY_COST,
        ARCADE_CHALLENGE_MAX_ENERGY,
    },
    ARCADE_NAMESPACE_HASH,
};
use crate::pvp::{GameStorage, GameTrait};
use crate::combatants::{CombatantStorage, CombatantTrait, CombatantState, CombatantSetup};
use crate::attacks::AttackStorage;
use crate::combat::{CombatTrait, CombatProgress};
use crate::world::{uuid, WorldTrait};
use crate::hash::{make_hash_state, felt252_to_u128};
use crate::stats::UStats;
use crate::collections::{TokenAttributes, CollectionGroupStorage, CollectionGroup};
use crate::constants::{STARTING_HEALTH, SECONDS_12_HOURS};
use crate::stats::StatsTrait;
use crate::iter::Iteration;
use crate::tags::{Tag, IdTagNew};
use crate::core::{byte_array_to_felt252_array, BoolIntoOneZero};
use crate::erc721::ERC721TokenStorage;
use crate::achievements::{Achievements, TaskId};

fn calc_restored_health(current_health: u8, vitality: u8, health_recovery_percent: u8) -> u8 {
    let max_health = STARTING_HEALTH + vitality;
    let health_recovery = (max_health.wide_mul(health_recovery_percent) / 100).try_into().unwrap();
    min(max_health, current_health + health_recovery)
}

fn get_arcade_challenge_id(
    name: @ByteArray, health_recovery: u8, opponents: Span<felt252>,
) -> felt252 {
    let mut output = byte_array_to_felt252_array(name);
    output.append(health_recovery.into());
    for id in opponents {
        output.append(*id);
    };
    poseidon_hash_span(output.span())
}

fn get_arcade_opponent_id(
    name: @ByteArray,
    collection: ContractAddress,
    attributes: @TokenAttributes,
    stats: @UStats,
    attack_ids: Span<felt252>,
) -> felt252 {
    let mut output = byte_array_to_felt252_array(name);
    output.append(collection.into());
    Serde::serialize(attributes, ref output);
    Serde::serialize(stats, ref output);
    for id in attack_ids {
        output.append(*id);
    };
    poseidon_hash_span(output.span())
}

#[generate_trait]
impl ArcadeImpl of ArcadeTrait {
    fn assert_collection_allowed(self: @WorldStorage, id: felt252, collection: ContractAddress) {
        assert(self.get_collection_allowed(id, collection), 'Collection not allowed');
    }

    fn new_arcade_game(
        ref self: ArcadeStore,
        opponent_token: felt252,
        player: ContractAddress,
        player_collection_address: ContractAddress,
        player_token_id: u256,
        player_attacks: Array<(felt252, felt252)>,
    ) -> felt252 {
        assert(
            self.arcade.get_collection_allowed(opponent_token, player_collection_address),
            'Collection not allowed',
        );
        let (game, _, _) = self
            .new_arcade_opponent_in_combat(
                player, player_collection_address, player_token_id, player_attacks, opponent_token,
            );
        self.ba.set_combatant_token(game.combatant_id, player_collection_address, player_token_id);
        game.id
    }
    fn new_arcade_opponent_in_combat(
        ref self: ArcadeStore,
        player: ContractAddress,
        player_collection_address: ContractAddress,
        player_token_id: u256,
        player_attacks: Array<(felt252, felt252)>,
        opponent_token: felt252,
    ) -> (ArcadeGame, UStats, Array<felt252>) {
        let (stats, attacks) = self
            .ba
            .get_token_stats_and_attacks(
                player_collection_address, player_token_id, player_attacks,
            );
        let game = self
            .setup_arcade_opponent_in_combat(
                player, stats, stats.get_max_health(), attacks.span(), opponent_token,
            );
        (game, stats, attacks)
    }


    fn setup_arcade_opponent_in_combat(
        ref self: ArcadeStore,
        player: ContractAddress,
        stats: UStats,
        health: u8,
        attacks: Span<felt252>,
        opponent_token: felt252,
    ) -> ArcadeGame {
        let game_id = uuid();
        let opponent_id = uuid();
        let combatant_id = uuid();
        self
            .ba
            .create_combatant_state(
                opponent_id, self.arcade.get_arcade_opponent_stats(opponent_token),
            );
        self.ba.set_combatant_stats_health_and_attacks(combatant_id, stats, health, attacks);
        self
            .arcade
            .new_arcade_game_model(game_id, combatant_id, player, opponent_token, opponent_id)
    }


    fn setup_new_opponent(
        ref self: WorldStorage,
        name: ByteArray,
        collection: ContractAddress,
        attributes: TokenAttributes,
        stats: UStats,
        attack_ids: Array<felt252>,
    ) -> felt252 {
        let token_id = get_arcade_opponent_id(
            @name, collection, @attributes, @stats, attack_ids.span(),
        );
        if !self.check_arcade_opponent_exists(token_id) {
            self.set_arcade_opponent(token_id, stats, attack_ids);
            self.set_tag(OPPONENT_TAG_GROUP, @name, token_id);
            self.set_arcade_info(token_id, name, collection, attributes);
        };
        token_id
    }

    fn setup_new_opponent_from_input(
        ref self: WorldStorage, opponent: ArcadeOpponentInput,
    ) -> felt252 {
        self
            .setup_new_opponent(
                opponent.name,
                opponent.collection,
                opponent.attributes,
                opponent.stats,
                self.create_or_get_attacks_external(opponent.attacks),
            )
    }
    fn make_opponent_model_from_input(
        ref self: WorldStorage, opponent: ArcadeOpponentInput,
    ) -> (ArcadeOpponent, @ByteArray, bool) {
        let attack_ids = self.create_or_get_attacks_external(opponent.attacks);
        let sname = @opponent.name;
        let id = get_arcade_opponent_id(
            sname, opponent.collection, @opponent.attributes, @opponent.stats, attack_ids.span(),
        );
        let exists = self.check_arcade_opponent_exists(id);
        if !exists {
            self.set_arcade_info(id, opponent.name, opponent.collection, opponent.attributes);
        };

        (ArcadeOpponent { id, stats: opponent.stats, attacks: attack_ids }, sname, exists)
    }

    fn create_or_get_opponent(
        ref self: WorldStorage, opponent: IdTagNew<ArcadeOpponentInput>,
    ) -> felt252 {
        match opponent {
            IdTagNew::Id(id) => id,
            IdTagNew::Tag(name) => self.get_tag(OPPONENT_TAG_GROUP, @name),
            IdTagNew::New(opponent) => self.setup_new_opponent_from_input(opponent),
        }
    }

    fn create_or_get_opponents(
        ref self: WorldStorage, opponents: Array<IdTagNew<ArcadeOpponentInput>>,
    ) -> Array<felt252> {
        let mut models = ArrayTrait::<@ArcadeOpponent>::new();
        let mut tags = ArrayTrait::<(@ByteArray, felt252)>::new();
        let mut ids = ArrayTrait::<felt252>::new();
        for opponent in opponents {
            ids
                .append(
                    match opponent {
                        IdTagNew::Id(id) => id,
                        IdTagNew::Tag(name) => self.get_tag(OPPONENT_TAG_GROUP, @name),
                        IdTagNew::New(opponent) => {
                            let (model, name, exists) = self
                                .make_opponent_model_from_input(opponent);
                            if !exists {
                                models.append(@model);
                                tags.append((name, model.id));
                            };
                            model.id
                        },
                    },
                );
        };
        self.set_arcade_opponents(models);
        self.set_tags(OPPONENT_TAG_GROUP, tags);
        ids
    }

    fn check_arcade_challenge_exists(self: @WorldStorage, id: felt252) -> bool {
        self.get_arcade_stage_opponent(id, 1).is_non_zero()
    }

    fn get_arcade_challenge_id(
        name: @ByteArray, health_recovery: u8, opponents: Span<felt252>,
    ) -> felt252 {
        let mut output = byte_array_to_felt252_array(name);
        output.append(health_recovery.into());
        for id in opponents {
            output.append(*id);
        };
        poseidon_hash_span(output.span())
    }

    fn setup_new_challenge(
        ref self: WorldStorage,
        name: ByteArray,
        health_recovery: u8,
        opponents: Array<IdTagNew<ArcadeOpponentInput>>,
        collections_allowed: Array<ContractAddress>,
    ) -> felt252 {
        let opponent_ids = self.create_or_get_opponents(opponents);
        let challenge_id = get_arcade_challenge_id(@name, health_recovery, opponent_ids.span());
        if !self.check_arcade_challenge_exists(challenge_id) {
            self.set_tag(CHALLENGE_TAG_GROUP, @name, challenge_id);
            self.emit_arcade_challenge_name(challenge_id, name);
            self.set_arcade_challenge(challenge_id, health_recovery);
            for (n, id) in opponent_ids.enumerate() {
                self.set_arcade_stage_opponent(challenge_id, n, id);
            }
        };
        self.set_collections_allowed(challenge_id, collections_allowed, true);
        challenge_id
    }

    fn run_arcade_round(
        ref self: ArcadeStore,
        game: ArcadeGame,
        player_attack: felt252,
        opponent_attacks: Array<felt252>,
        randomness: felt252,
    ) {
        assert(game.phase == ArcadePhase::Active, 'Not active');
        let hash = make_hash_state(randomness);
        let combatants = [game.combatant_id, game.opponent_id];
        let attacks = [
            player_attack, self.ba.get_opponent_attack(@game, opponent_attacks, randomness),
        ];
        let (progress, results) = self
            .ba
            .run_round(game.id, game.round, combatants, attacks, [false, true], hash);
        match progress {
            CombatProgress::Active => { self.arcade.set_arcade_round(game.id, game.round + 1); },
            CombatProgress::Ended([winner, _]) => self
                .arcade
                .set_arcade_ended(game.id, winner == game.combatant_id),
        }
        for result in results {
            if result.combatant_id == game.combatant_id {
                let new_attack_uses: u32 = self
                    .arcade
                    .increment_attack_uses(game.player, player_attack)
                    .is_zero()
                    .into();

                let (_, opponent) = result.effects();
                let mut damage = opponent.damage;
                if opponent.health < 0 {
                    damage += (-opponent.health).try_into().unwrap();
                };
                self
                    .arcade
                    .progress_achievements_now(
                        game.player,
                        array![
                            (TaskId::ArcadeUniqueMoves, new_attack_uses),
                            (TaskId::ArcadeTotalDamage, damage),
                            (TaskId::CriticalHits, opponent.criticals),
                        ],
                    );
            }
        };
    }
    fn get_opponent_attack(
        ref self: WorldStorage, game: @ArcadeGame, attacks: Array<felt252>, randomness: felt252,
    ) -> felt252 {
        let (mut n, n_attacks) = (0, attacks.len());
        let sn = (felt252_to_u128(randomness) % n_attacks.into()).try_into().unwrap();
        loop {
            let i = (n + sn);
            let id = if i < n_attacks {
                *attacks[i]
            } else {
                *attacks[i - n_attacks]
            };
            if self.run_attack_cooldown(*game.opponent_id, id, *game.round) {
                break id;
            };
            n += 1;
            if n == n_attacks {
                break 0;
            };
        }
    }

    fn get_arcade_players_challenge_attempt(
        self: @WorldStorage, id: felt252,
    ) -> ArcadeChallengeAttempt {
        let attempt = self.get_arcade_challenge_attempt(id);
        assert(attempt.player == get_caller_address(), 'Not player');
        attempt.phase.assert_active();
        attempt
    }

    fn new_arcade_challenge_attempt(
        ref self: ArcadeStore,
        challenge_id: felt252,
        player: ContractAddress,
        collection: ContractAddress,
        token_id: u256,
        attacks: Array<(felt252, felt252)>,
    ) -> (felt252, felt252) {
        self.arcade.assert_collection_allowed(challenge_id, collection);
        let id = uuid();
        let timestamp = get_block_timestamp();
        self.arcade.use_game(player, timestamp);

        let (stats, attacks) = self.ba.get_token_stats_and_attacks(collection, token_id, attacks);
        let attempt = self
            .arcade
            .new_arcade_challenge_attempt(
                id, challenge_id, player, collection, token_id, stats, attacks, timestamp,
            );
        self.arcade.set_arcade_current_challenge_attempt(player, collection, token_id, id);
        let game_id = self
            .create_arcade_challenge_attempt_round(
                attempt.id,
                attempt.challenge,
                attempt.player,
                attempt.stats,
                attempt.attacks,
                attempt.stage,
                stats.get_max_health(),
            );
        (id, game_id)
    }

    fn next_arcade_challenge_round(ref self: ArcadeStore, attempt_id: felt252) -> felt252 {
        let mut attempt = self.arcade.get_arcade_challenge_attempt_next_stage(attempt_id);
        assert(attempt.player == get_caller_address(), 'Not player');
        attempt.phase.assert_active();
        let (combatant_id, phase) = self
            .arcade
            .get_arcade_game_combatant_phase(
                self.arcade.get_arcade_stage_game_id(attempt_id, attempt.stage),
            );
        assert(phase == ArcadePhase::PlayerWon, 'Player not won last round');
        assert(get_block_timestamp() <= attempt.expiry, 'Challenge expired');
        let health = calc_restored_health(
            self.ba.get_combatant_health(combatant_id),
            attempt.stats.vitality,
            self.arcade.get_arcade_challenge_health_recovery(attempt.challenge),
        );

        attempt.stage += 1;

        self.arcade.set_arcade_challenge_stage(attempt_id, attempt.stage);

        self
            .create_arcade_challenge_attempt_round(
                attempt_id,
                attempt.challenge,
                attempt.player,
                attempt.stats,
                attempt.attacks,
                attempt.stage,
                health,
            )
    }

    fn create_arcade_challenge_attempt_round(
        ref self: ArcadeStore,
        id: felt252,
        challenge: felt252,
        player: ContractAddress,
        stats: UStats,
        attacks: Array<felt252>,
        stage: u32,
        health: u8,
    ) -> felt252 {
        let opponent = self.arcade.get_arcade_stage_opponent(challenge, stage);
        assert(opponent.is_non_zero(), 'No more stages');
        let game = self
            .setup_arcade_opponent_in_combat(player, stats, health, attacks.span(), opponent);
        self.arcade.set_arcade_stage_game(id, stage, game.id);
        game.id
    }

    fn respawn_arcade_challenge_attempt(ref self: ArcadeStore, attempt_id: felt252) -> felt252 {
        let mut attempt = self.arcade.get_arcade_challenge_attempt_respawn(attempt_id);
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
            .create_arcade_challenge_attempt_round(
                attempt_id,
                attempt.challenge,
                attempt.player,
                attempt.stats,
                attempt.attacks,
                attempt.stage,
                health,
            )
    }


    fn end_arcade_challenge_attempt(
        ref self: WorldStorage, attempt_id: felt252, attempt: ArcadeAttemptEnd,
    ) {
        attempt.phase.assert_active();
        let game_id = self.get_arcade_stage_game_id(attempt_id, attempt.stage);
        let won = match self.get_arcade_game_phase(game_id) {
            ArcadePhase::PlayerWon => {
                self.get_arcade_stage_opponent(attempt.challenge, attempt.stage + 1).is_zero()
            },
            ArcadePhase::PlayerLost => false,
            ArcadePhase::Active => {
                self.set_arcade_ended(game_id, false);
                false
            },
            _ => panic!("Combat not started"),
        };
        self
            .remove_arcade_current_challenge_attempt(
                attempt.player, attempt.collection, attempt.token_id,
            );
        self.set_arcade_challenge_attempt_ended(attempt_id, won);
        let timestamp = get_block_timestamp();
        if won {
            match self.default_storage().get_collection_group(attempt.collection) {
                CollectionGroup::ClassicBlobert |
                CollectionGroup::FreeBlobert => {
                    self
                        .increment_achievement(
                            attempt.player, TaskId::ClassicArcadeCompletion, timestamp,
                        );
                },
                CollectionGroup::AmmaBlobert => {
                    self
                        .increment_achievement(
                            attempt.player, TaskId::AmmaArcadeCompletion, timestamp,
                        );
                },
                _ => {},
            };
            if attempt.respawns.is_zero() {
                self
                    .increment_achievement(
                        attempt.player, TaskId::ArcadeCompletionNoRespawn, timestamp,
                    );
            }
        }
    }

    fn use_free_game(ref self: WorldStorage, player: ContractAddress, timestamp: u64) -> bool {
        let model = self.get_free_games(player);
        let mut energy = model.energy + timestamp - model.timestamp;

        if energy >= ARCADE_CHALLENGE_GAME_ENERGY_COST {
            if energy > ARCADE_CHALLENGE_MAX_ENERGY {
                energy = ARCADE_CHALLENGE_MAX_ENERGY;
            };
            self.set_free_games(player, energy - ARCADE_CHALLENGE_GAME_ENERGY_COST, timestamp);
            true
        } else {
            false
        }
    }

    fn use_paid_game(ref self: WorldStorage, player: ContractAddress) {
        let games = self.get_number_of_paid_games(player);
        assert(games > 0, 'No paid games');
        self.set_number_of_paid_games(player, games - 1);
    }

    fn use_game(ref self: WorldStorage, player: ContractAddress, timestamp: u64) {
        let mut store = self.storage(ARCADE_NAMESPACE_HASH);
        if !store.use_free_game(player, timestamp) {
            store.use_paid_game(player);
        };
    }

    fn increase_number_of_paid_games<S, +WorldTrait<S>, +Drop<S>>(
        ref self: S, player: ContractAddress, amount: u32,
    ) {
        let mut store = self.storage(ARCADE_NAMESPACE_HASH);
        let games = store.get_number_of_paid_games(player);
        store.set_number_of_paid_games(player, games + amount);
    }

    fn get_arcade_attempt_game(self: @WorldStorage, attempt_id: felt252) -> ArcadeGame {
        let ArcadeAttemptGetGame { challenge, stage } = self.get_arcade_challenge_stage(attempt_id);
        self.get_arcade_game(self.get_arcade_stage_game_id(challenge, stage))
    }
}
