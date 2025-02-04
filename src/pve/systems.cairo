use core::cmp::min;
use starknet::{ContractAddress, get_contract_address, get_block_timestamp};
use dojo::world::WorldStorage;
use blob_arena::{
    attacks::Attack,
    pve::{
        PVEGame, PVEOpponent, PVEBlobertInfo, PVEStorage, PVEPhase, PVEStore,
        components::PVEPlayerPhase,
    },
    game::{GameStorage, GameTrait, GameProgress},
    combatants::{CombatantStorage, CombatantTrait, CombatantState, CombatantSetup},
    attacks::AttackStorage, combat::CombatTrait, world::uuid,
    hash::{make_hash_state, felt252_to_u128}, stats::UStats, collections::blobert::TokenAttributes,
    constants::{STARTING_HEALTH, SECONDS_12_HOURS}, stats::StatsTrait,
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
        let (combatant_id, _) = self
            .ba
            .new_pve_combatant(player_collection_address, player_token_id, player_attacks);
        let game_id = uuid();
        self.pve.set_combatant_info(combatant_id, game_id, player);
        self.new_pve_combat(game_id, opponent_token);

        game_id
    }

    fn new_pve_combat(ref self: PVEStore, game_id: felt252, opponent_token: felt252) {
        let opponent_id = uuid();
        self
            .ba
            .create_combatant_state(opponent_id, self.pve.get_pve_opponent_stats(opponent_token));
        self.pve.new_pve_game_model(game_id, opponent_token, opponent_id);
    }

    fn new_pve_combatant(
        ref self: WorldStorage,
        player_collection_address: ContractAddress,
        player_token_id: u256,
        player_attacks: Array<(felt252, felt252)>,
    ) -> (felt252, CombatantSetup) {
        let player_id = uuid();
        self.set_combatant_token(player_id, player_collection_address, player_token_id);
        let setup = self
            .setup_combatant_state_and_attacks(
                player_id, player_collection_address, player_token_id, player_attacks,
            );
        (player_id, setup)
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
    fn run_pve_round(
        ref self: PVEStore,
        combatant_id: felt252,
        game: PVEGame,
        player_attack: felt252,
        randomness: felt252,
    ) {
        assert(game.phase == PVEPhase::Active, 'Not active');
        let hash = make_hash_state(randomness);
        let combatants = [combatant_id, game.opponent_id];
        let opponent_attacks = self.pve.get_pve_opponent_attacks(game.opponent_token);
        let attacks = [
            player_attack, self.ba.get_opponent_attack(@game, opponent_attacks, randomness),
        ];
        match self.ba.run_round(game.id, game.round, combatants, attacks, [false, true], hash) {
            GameProgress::Active => { self.pve.set_pve_round(game.id, game.round + 1); },
            GameProgress::Ended([winner, _]) => self
                .pve
                .set_pve_ended(game.id, winner == combatant_id),
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

    fn new_pve_challenge(
        ref self: PVEStore,
        challenge_id: felt252,
        player: ContractAddress,
        player_collection_address: ContractAddress,
        player_token_id: u256,
        player_attacks: Array<(felt252, felt252)>,
    ) -> felt252 {
        let id = uuid();

        let (combatant_id, CombatantSetup { stats, attacks }) = self
            .ba
            .new_pve_combatant(player_collection_address, player_token_id, player_attacks);
        self.pve.set_combatant_info(combatant_id, id, player);
        self.pve.assert_collection_allowed(challenge_id, player_collection_address);
        self.pve.new_pve_challenge_attempt(id, challenge_id, stats, attacks);
        self.create_pve_challenge_attempt_round(id, challenge_id, player, combatant_id, 1);

        id
    }

    fn next_pve_challenge_round(ref self: PVEStore, attempt_id: felt252) {
        let attempt = self.pve.get_pve_challenge_attempt(attempt_id);

        let PVEPlayerPhase {
            player, phase, combatant_id,
        } = self.pve.get_pve_stage_game_phase_and_player(attempt_id, attempt.stage);

        assert(attempt.stage.is_non_zero(), 'Not Started');
        match phase {
            PVEPhase::Ended(won) => assert(won, 'Player Lost'),
            _ => panic!("Combat not ended"),
        };
        let stage = attempt.stage + 1;
        self.pve.set_pve_challenge_stage(attempt_id, stage);

        let health = calc_restored_health(
            self.ba.get_combatant_health(combatant_id),
            attempt.stats.vitality,
            self.pve.get_pve_challenge_health_recovery(attempt_id),
        );

        self.ba.reset_combatant(combatant_id, health, attempt.stats, attempt.attacks);

        self.create_pve_challenge_attempt_round(attempt_id, attempt.challenge, combatant_id, stage);
    }

    fn create_pve_challenge_attempt_round(
        ref self: PVEStore,
        attempt_id: felt252,
        challenge_id: felt252,
        combatant_id: felt252,
        stage: u32,
    ) {
        let opponent = self.pve.get_pve_stage_opponent(challenge_id, stage);
        assert(opponent.is_non_zero(), 'No more stages');
        self.new_pve_combat(attempt_id, opponent);
    }

    fn respawn(ref self: PVEStore, attempt_id: felt252) {
        let attempt = self.pve.get_pve_challenge_attempt(attempt_id);

        let PVEPlayerPhase {
            player, phase, combatant_id,
        } = self.pve.get_pve_stage_game_phase_and_player(attempt_id, attempt.stage);
        assert(attempt.respawns.is_zero(), 'No more respawns');
        assert(attempt.stage.is_non_zero(), 'Not Started');
        match phase {
            PVEPhase::Ended(won) => assert(!won, 'Player not dead'),
            _ => panic!("Combat not ended"),
        };

        self
            .ba
            .reset_combatant(
                combatant_id, attempt.stats.get_max_health(), attempt.stats, attempt.attacks,
            );

        self.pve.set_pve_challenge_respawns(attempt_id, attempt.respawns + 1);
    }

    fn create_pve_challenge_round(
        ref self: PVEStore,
        challenge_id: felt252,
        stages: felt252,
        player: ContractAddress,
        combatant_id: felt252,
        stage: u32,
    ) -> bool {
        let opponent = self.pve.get_pve_stage_opponent(stages, stage);
        if opponent.is_non_zero() {
            true
        } else {
            false
        }
    }


    fn use_free_game(ref self: WorldStorage, player: ContractAddress) {
        let games = self.get_number_free_games(player);
        assert(games > 0, 'No free games');
        self.set_number_free_games(player, games - 1);
    }

    fn mint_free_game(ref self: WorldStorage, player: ContractAddress) {
        let model = self.get_free_games(player);
        assert(model.games < 2, 'No free games');
        let timestamp = get_block_timestamp();
        assert(model.last_claim + SECONDS_12_HOURS <= timestamp, 'Not enough time passed');
        self.set_free_games(player, model.games + 1, timestamp);
    }
}
