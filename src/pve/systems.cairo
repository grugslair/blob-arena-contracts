use core::{cmp::min, poseidon::poseidon_hash_span, num::traits::WideMul};
use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_timestamp};
use dojo::world::WorldStorage;
use blob_arena::{
    attacks::{Attack, AttackInput, AttackTrait},
    pve::{
        PVEGame, PVEOpponent, PVEOpponentInput, PVEBlobertInfo, PVEStorage, PVEPhase, PVEStore,
        PVEChallengeAttempt, PVEPhaseTrait, PVEEndAttemptSchema,
        components::{OPPONENT_TAG_GROUP, CHALLENGE_TAG_GROUP},
    },
    game::{GameStorage, GameTrait, GameProgress},
    combatants::{CombatantStorage, CombatantTrait, CombatantState, CombatantSetup},
    attacks::AttackStorage, combat::CombatTrait, world::uuid,
    hash::{make_hash_state, felt252_to_u128}, stats::UStats, collections::blobert::TokenAttributes,
    constants::{STARTING_HEALTH, SECONDS_12_HOURS}, stats::StatsTrait, iter::Iteration,
    tags::{Tag, IdTagNew}, core::byte_array_to_felt252_array,
};

fn calc_restored_health(current_health: u8, vitality: u8, health_recovery_percent: u8) -> u8 {
    let max_health = STARTING_HEALTH + vitality;
    let health_recovery = (max_health.wide_mul(health_recovery_percent) / 100).try_into().unwrap();
    min(max_health, current_health + health_recovery)
}

fn get_pve_challenge_id(
    name: @ByteArray, health_recovery: u8, opponents: Span<felt252>,
) -> felt252 {
    let mut output = byte_array_to_felt252_array(name);
    output.append(health_recovery.into());
    for id in opponents {
        output.append(*id);
    };
    poseidon_hash_span(output.span())
}

fn get_pve_opponent_id(
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
impl PVEImpl of PVETrait {
    fn assert_collection_allowed(self: @WorldStorage, id: felt252, collection: ContractAddress) {
        assert(self.get_collection_allowed(id, collection), 'Collection not allowed');
    }

    fn new_pve_game(
        ref self: PVEStore,
        opponent_token: felt252,
        player: ContractAddress,
        player_collection_address: ContractAddress,
        player_token_id: u256,
        player_attacks: Array<(felt252, felt252)>,
    ) -> felt252 {
        assert(
            self.pve.get_collection_allowed(opponent_token, player_collection_address),
            'Collection not allowed',
        );
        let (game, _, _) = self
            .new_pve_opponent_in_combat(
                player, player_collection_address, player_token_id, player_attacks, opponent_token,
            );
        self.ba.set_combatant_token(game.combatant_id, player_collection_address, player_token_id);
        game.id
    }
    fn new_pve_opponent_in_combat(
        ref self: PVEStore,
        player: ContractAddress,
        player_collection_address: ContractAddress,
        player_token_id: u256,
        player_attacks: Array<(felt252, felt252)>,
        opponent_token: felt252,
    ) -> (PVEGame, UStats, Array<felt252>) {
        let (stats, attacks) = self
            .ba
            .get_token_stats_and_attacks(
                player_collection_address, player_token_id, player_attacks,
            );
        let game = self
            .setup_pve_opponent_in_combat(
                player, stats, stats.get_max_health(), attacks.span(), opponent_token,
            );
        (game, stats, attacks)
    }


    fn setup_pve_opponent_in_combat(
        ref self: PVEStore,
        player: ContractAddress,
        stats: UStats,
        health: u8,
        attacks: Span<felt252>,
        opponent_token: felt252,
    ) -> PVEGame {
        let game_id = uuid();
        let opponent_id = uuid();
        let combatant_id = uuid();
        self
            .ba
            .create_combatant_state(opponent_id, self.pve.get_pve_opponent_stats(opponent_token));
        self.ba.set_combatant_stats_health_and_attacks(combatant_id, stats, health, attacks);
        self.pve.new_pve_game_model(game_id, combatant_id, player, opponent_token, opponent_id)
    }


    fn setup_new_opponent(
        ref self: WorldStorage,
        name: ByteArray,
        collection: ContractAddress,
        attributes: TokenAttributes,
        stats: UStats,
        attack_ids: Array<felt252>,
        collections_allowed: Array<ContractAddress>,
    ) -> felt252 {
        let token_id = get_pve_opponent_id(
            @name, collection, @attributes, @stats, attack_ids.span(),
        );
        if !self.check_pve_opponent_exists(token_id) {
            self.set_pve_opponent(token_id, stats, attack_ids);
            self.set_tag(OPPONENT_TAG_GROUP, @name, token_id);
            self.set_pve_blobert_info(token_id, name, collection, attributes);
        };
        self.set_collections_allowed(token_id, collections_allowed, true);
        token_id
    }

    fn setup_new_opponent_from_input(
        ref self: WorldStorage, opponent: PVEOpponentInput,
    ) -> felt252 {
        self
            .setup_new_opponent(
                opponent.name,
                opponent.collection,
                opponent.attributes,
                opponent.stats,
                self.create_or_get_attacks_external(opponent.attacks),
                opponent.collections_allowed,
            )
    }
    fn make_opponent_model_from_input(
        ref self: WorldStorage, opponent: PVEOpponentInput,
    ) -> (PVEOpponent, @ByteArray, bool) {
        let attack_ids = self.create_or_get_attacks_external(opponent.attacks);
        let sname = @opponent.name;
        let id = get_pve_opponent_id(
            sname, opponent.collection, @opponent.attributes, @opponent.stats, attack_ids.span(),
        );
        let exists = self.check_pve_opponent_exists(id);
        if !exists {
            self.set_pve_blobert_info(id, opponent.name, opponent.collection, opponent.attributes);
        };

        self.set_collections_allowed(id, opponent.collections_allowed, true);

        (PVEOpponent { id, stats: opponent.stats, attacks: attack_ids }, sname, exists)
    }

    fn create_or_get_opponent(
        ref self: WorldStorage, opponent: IdTagNew<PVEOpponentInput>,
    ) -> felt252 {
        match opponent {
            IdTagNew::Id(id) => id,
            IdTagNew::Tag(name) => self.get_tag(OPPONENT_TAG_GROUP, @name),
            IdTagNew::New(opponent) => self.setup_new_opponent_from_input(opponent),
        }
    }

    fn create_or_get_opponents(
        ref self: WorldStorage, opponents: Array<IdTagNew<PVEOpponentInput>>,
    ) -> Array<felt252> {
        let mut models = ArrayTrait::<@PVEOpponent>::new();
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
        self.set_pve_opponents(models);
        self.set_tags(OPPONENT_TAG_GROUP, tags);
        ids
    }

    fn check_pve_challenge_exists(self: @WorldStorage, id: felt252) -> bool {
        self.get_pve_stage_opponent(id, 1).is_non_zero()
    }

    fn get_pve_challenge_id(
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
        opponents: Array<IdTagNew<PVEOpponentInput>>,
        collections_allowed: Array<ContractAddress>,
    ) {
        let opponent_ids = self.create_or_get_opponents(opponents);
        let challenge_id = get_pve_challenge_id(@name, health_recovery, opponent_ids.span());
        if !self.check_pve_challenge_exists(challenge_id) {
            self.set_tag(CHALLENGE_TAG_GROUP, @name, challenge_id);
            self.emit_pve_challenge_name(challenge_id, name);
            self.set_pve_challenge(challenge_id, health_recovery);
            for (n, id) in opponent_ids.enumerate() {
                self.set_pve_stage_opponent(challenge_id, n, id);
            }
        };
        self.set_collections_allowed(challenge_id, collections_allowed, true);
    }

    fn run_pve_round(
        ref self: PVEStore, game: PVEGame, player_attack: felt252, randomness: felt252,
    ) {
        assert(game.phase == PVEPhase::Active, 'Not active');
        let hash = make_hash_state(randomness);
        let combatants = [game.combatant_id, game.opponent_id];
        let opponent_attacks = self.pve.get_pve_opponent_attacks(game.opponent_token);
        let attacks = [
            player_attack, self.ba.get_opponent_attack(@game, opponent_attacks, randomness),
        ];
        match self.ba.run_round(game.id, game.round, combatants, attacks, [false, true], hash) {
            GameProgress::Active => { self.pve.set_pve_round(game.id, game.round + 1); },
            GameProgress::Ended([winner, _]) => self
                .pve
                .set_pve_ended(game.id, winner == game.combatant_id),
        }
    }
    fn get_opponent_attack(
        ref self: WorldStorage, game: @PVEGame, attacks: Array<felt252>, randomness: felt252,
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

    fn get_pve_players_challenge_attempt(self: @WorldStorage, id: felt252) -> PVEChallengeAttempt {
        let attempt = self.get_pve_challenge_attempt(id);
        assert(attempt.player == get_caller_address(), 'Not player');
        attempt.phase.assert_active();
        attempt
    }

    fn new_pve_challenge_attempt(
        ref self: PVEStore,
        challenge_id: felt252,
        player: ContractAddress,
        player_collection_address: ContractAddress,
        player_token_id: u256,
        player_attacks: Array<(felt252, felt252)>,
    ) -> felt252 {
        self.pve.assert_collection_allowed(challenge_id, player_collection_address);
        let id = uuid();
        let (stats, attacks) = self
            .ba
            .get_token_stats_and_attacks(
                player_collection_address, player_token_id, player_attacks,
            );
        let attempt = self.pve.new_pve_challenge_attempt(id, challenge_id, player, stats, attacks);

        self.create_pve_challenge_attempt_round(attempt, stats.get_max_health());
        id
    }

    fn next_pve_challenge_round(ref self: PVEStore, mut attempt: PVEChallengeAttempt) {
        let (combatant_id, phase) = self
            .pve
            .get_pve_game_combatant_phase(
                self.pve.get_pve_stage_game_id(attempt.id, attempt.stage),
            );
        assert(phase == PVEPhase::PlayerWon, 'Player not won last round');

        let health = calc_restored_health(
            self.ba.get_combatant_health(combatant_id),
            attempt.stats.vitality,
            self.pve.get_pve_challenge_health_recovery(attempt.challenge),
        );

        attempt.stage += 1;

        self.pve.set_pve_challenge_stage(attempt.id, attempt.stage);
        self.create_pve_challenge_attempt_round(attempt, health);
    }

    fn create_pve_challenge_attempt_round(
        ref self: PVEStore, attempt: PVEChallengeAttempt, health: u8,
    ) {
        let opponent = self.pve.get_pve_stage_opponent(attempt.challenge, attempt.stage);
        assert(opponent.is_non_zero(), 'No more stages');
        let game = self
            .setup_pve_opponent_in_combat(
                attempt.player, attempt.stats, health, attempt.attacks.span(), opponent,
            );
        self.pve.set_pve_stage_game(attempt.id, attempt.stage, game.id);
    }

    fn respawn_pve_challenge_attempt(ref self: PVEStore, mut attempt: PVEChallengeAttempt) {
        let game_id = self.pve.get_pve_stage_game_id(attempt.id, attempt.stage);
        let phase = self.pve.get_pve_game_phase(game_id);

        assert(attempt.respawns.is_zero(), 'No more respawns');
        assert(phase == PVEPhase::PlayerLost, 'Player not lost round');
        attempt.respawns += 1;

        self.pve.set_pve_challenge_respawns(attempt.id, attempt.respawns);
        self.pve.emit_pve_respawn(@attempt, game_id);
        let health = attempt.stats.get_max_health();
        self.create_pve_challenge_attempt_round(attempt, health);
    }

    fn end_pve_challenge_attempt(
        ref self: WorldStorage, attempt_id: felt252, attempt: PVEEndAttemptSchema,
    ) {
        attempt.phase.assert_active();
        let phase = self.get_pve_game_phase(self.get_pve_stage_game_id(attempt_id, attempt.stage));
        let won = match phase {
            PVEPhase::PlayerWon => {
                assert(
                    self.get_pve_stage_game_id(attempt.challenge, attempt.stage + 1).is_zero(),
                    'Not last stage',
                );
                true
            },
            PVEPhase::PlayerLost => false,
            _ => panic!("Combat not ended"),
        };
        self.set_pve_challenge_attempt_ended(attempt_id, won);
    }


    fn use_free_game(ref self: WorldStorage, player: ContractAddress) -> bool {
        let games = self.get_number_free_games(player);
        let available = games > 0;
        if available {
            self.set_number_free_games(player, games - 1);
        };
        available
    }
    fn use_paid_game(ref self: WorldStorage, player: ContractAddress) {
        panic!("Paid games not implemented");
    }

    fn mint_free_game(ref self: WorldStorage, player: ContractAddress) {
        let model = self.get_free_games(player);
        assert(model.games < 2, 'No free games');
        let timestamp = get_block_timestamp();
        assert(model.last_claim + SECONDS_12_HOURS <= timestamp, 'Not enough time passed');
        self.set_free_games(player, model.games + 1, timestamp);
    }

    fn use_game(ref self: WorldStorage, player: ContractAddress) {
        if !self.use_free_game(player) {
            self.use_paid_game(player);
        };
    }
}
