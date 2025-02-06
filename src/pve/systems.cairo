use core::cmp::min;
use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_timestamp};
use dojo::world::WorldStorage;
use blob_arena::{
    attacks::Attack,
    pve::{
        PVEGame, PVEOpponent, PVEBlobertInfo, PVEStorage, PVEPhase, PVEStore, PVEChallengeAttempt,
        PVEPhaseTrait, PVEEndAttemptSchema,
    },
    game::{GameStorage, GameTrait, GameProgress},
    combatants::{CombatantStorage, CombatantTrait, CombatantState, CombatantSetup},
    attacks::AttackStorage, combat::CombatTrait, world::uuid,
    hash::{make_hash_state, felt252_to_u128}, stats::UStats, collections::blobert::TokenAttributes,
    constants::{STARTING_HEALTH, SECONDS_12_HOURS}, stats::StatsTrait, iter::Iteration,
};

fn calc_restored_health(current_health: u8, vitality: u8, health_recovery_percent: u8) -> u8 {
    let max_health = STARTING_HEALTH + vitality;
    let health_recovery = max_health * health_recovery_percent / 100;
    min(max_health, current_health + health_recovery)
}

#[generate_trait]
impl PVEImpl of PVETrait {
    fn assert_collection_allowed(self: @WorldStorage, id: felt252, collection: ContractAddress) {
        assert(self.get_collection_allowed(id, collection), 'Collection not allowed');
    }

    fn new_pve_game(
        ref self: PVEStore,
        player: ContractAddress,
        player_collection_address: ContractAddress,
        player_token_id: u256,
        player_attacks: Array<(felt252, felt252)>,
        opponent_token: felt252,
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
        attacks: Array<felt252>,
        collections_allowed: Array<ContractAddress>,
    ) -> felt252 {
        let token_id = uuid();
        self.set_pve_opponent(token_id, stats, attacks);
        self.set_pve_blobert_info(token_id, name, collection, attributes);
        self.set_collections_allowed(token_id, collections_allowed, true);
        token_id
    }

    fn setup_new_challenge(
        ref self: WorldStorage,
        name: ByteArray,
        health_recovery: u8,
        opponents: Array<felt252>,
        collections_allowed: Array<ContractAddress>,
    ) {
        let challenge_id = uuid();
        self.emit_pve_challenge_name(challenge_id, name);
        self.set_pve_challenge(challenge_id, health_recovery);
        self.set_collections_allowed(challenge_id, collections_allowed, true);
        for (n, opponent) in opponents.enumerate() {
            self.set_pve_stage_opponent(challenge_id, n, opponent);
        }
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
        assert(attempt.stage.is_non_zero(), 'Not Started');
        match phase {
            PVEPhase::Ended(won) => assert(won, 'Player Lost'),
            _ => panic!("Combat not ended"),
        };

        let health = calc_restored_health(
            self.ba.get_combatant_health(combatant_id),
            attempt.stats.vitality,
            self.pve.get_pve_challenge_health_recovery(attempt.id),
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

    fn respawn_pve_challenge_attempt(ref self: PVEStore, attempt: PVEChallengeAttempt) {
        let phase = self
            .pve
            .get_pve_game_phase(self.pve.get_pve_stage_game_id(attempt.id, attempt.stage));

        assert(attempt.respawns.is_zero(), 'No more respawns');
        assert(attempt.stage.is_non_zero(), 'Not Started');
        match phase {
            PVEPhase::Ended(won) => assert(!won, 'Player not dead'),
            _ => panic!("Combat not ended"),
        };
        self.pve.set_pve_challenge_respawns(attempt.id, attempt.respawns + 1);
        let health = attempt.stats.get_max_health();
        self.create_pve_challenge_attempt_round(attempt, health);
    }

    fn end_pve_challenge_attempt(
        ref self: WorldStorage, attempt_id: felt252, attempt: PVEEndAttemptSchema,
    ) {
        attempt.phase.assert_active();
        let phase = self.get_pve_game_phase(self.get_pve_stage_game_id(attempt_id, attempt.stage));
        let won = match phase {
            PVEPhase::Ended(won) => won,
            _ => panic!("Combat not ended"),
        };
        if won {
            assert(
                self.get_pve_stage_game_id(attempt_id, attempt.stage + 1).is_zero(),
                'Not last stage',
            );
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
