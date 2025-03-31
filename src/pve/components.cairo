use starknet::{ContractAddress, get_caller_address, get_block_timestamp};

use dojo::model::ModelValueStorage;
use dojo::world::WorldStorage;
use dojo::model::{ModelStorage, Model};
use dojo::event::EventStorage;
use dojo::meta::Introspect;

use crate::attacks::AttackInput;
use crate::stats::UStats;
use crate::tags::IdTagNew;
use crate::collections::TokenAttributes;

const PVE_NAMESPACE_HASH: felt252 = bytearray_hash!("pve_blobert");
const OPPONENT_TAG_GROUP: felt252 = 'pve-opponent';
const CHALLENGE_TAG_GROUP: felt252 = 'pve-challenge';
const ARCADE_CHALLENGE_TIME_LIMIT: u64 = 60 * 60 * 2; // 2 hours
const ARCADE_CHALLENGE_MAX_RESPAWNS: u32 = 3;

#[derive(Drop, Copy, Introspect, PartialEq, Serde)]
enum PVEPhase {
    None,
    Active,
    PlayerWon,
    PlayerLost,
}

fn end_phase(won: bool) -> PVEPhase {
    match won {
        true => PVEPhase::PlayerWon,
        false => PVEPhase::PlayerLost,
    }
}

#[generate_trait]
impl PVEPhaseImpl of PVEPhaseTrait {
    fn assert_active(self: PVEPhase) {
        assert(self == PVEPhase::Active, 'Phase not active');
    }
}

///////////////// Setup models

/// A model representing a PVE (Player vs Environment) opponent in the game
///
/// # Fields
/// * `id` - Unique Id of the opponent as a field element
/// * `stats` - Starting stats of the opponent using the UStats structure
/// * `attacks` - Array of attack IDs available to this opponent as field elements
#[dojo::model]
#[derive(Drop, Serde)]
struct PVEOpponent {
    #[key]
    id: felt252,
    stats: UStats,
    attacks: Array<felt252>,
    xp: u128,
}

/// Event emitted when for a pve blobert for off chain use only
/// # Arguments
/// * `id` - Unique Id for the blobert
/// * `name` - The name of the blobert
/// * `collection` - The contract address of the collection the blobert belongs to
/// * `attributes` - The attributes of the blobert token
#[dojo::event]
#[derive(Drop, Serde)]
struct PVEBlobertInfo {
    #[key]
    id: felt252,
    name: ByteArray,
    collection: ContractAddress,
    attributes: TokenAttributes,
}

/// Records a PVE Challenge within the game, identified by a unique ID.
///
/// # Arguments
/// * `id` - A unique Id for the PVE challenge
/// * `health_recovery` - Amount of health recovered after each round as a percentage of max health
#[dojo::model]
#[derive(Drop, Serde)]
struct PVEChallenge {
    #[key]
    id: felt252,
    health_recovery: u8,
}

/// Event emitted when a PVE challenge name is set
/// # Arguments
/// * `id` - The unique Id of the PVE challenge
/// * `name` - The name of the PVE challenge as a ByteArray
#[dojo::event]
#[derive(Drop, Serde)]
struct PVEChallengeName {
    #[key]
    id: felt252,
    name: ByteArray,
}

/// A model representing an opponent in a specific stage of a PVE challenge
///
/// # Fields
/// * `challenge_id` - Id for the PVE challenge
/// * `stage` - Stage number within the challenge
/// * `opponent` - Id of the opponent at this stage
#[dojo::model]
#[derive(Drop, Serde)]
struct PVEStageOpponent {
    #[key]
    challenge_id: felt252,
    #[key]
    stage: u32,
    opponent: felt252,
}

/// Represents a permission model for PVE (Player vs Environment) collections
///
/// # Arguments
/// * `id` - A unique identifier for the permission entry (Challenge or opponent id)
/// * `collection` - The contract address of the collection
/// * `allowed` - A boolean flag indicating whether the collection is allowed in PVE
///
/// This model is used to manage which NFT collections are permitted to participate
/// in PVE gameplay scenarios
#[dojo::model]
#[derive(Drop, Serde)]
struct PVECollectionAllowed {
    #[key]
    id: felt252,
    #[key]
    collection: ContractAddress,
    allowed: bool,
}

//////////////////// Game Models

/// Instance of combat against PVEOpponent
/// A PVEGame represents a player versus environment game instance
///
/// # Arguments
/// * `id` - Unique identifier for the game instance
/// * `player` - Contract address of the player
/// * `player_token` - Token identifier for the player
/// * `player_combatant` - Identifier for the player's combatant
/// * `opponent_token` - Token identifier for the opponent
/// * `opponent_combatant` - Identifier for the opponent combatant
/// * `round` - Current round number of the game
/// * `phase` - Current phase of the game
#[dojo::model]
#[derive(Drop, Serde)]
struct PVEGame {
    #[key]
    id: felt252,
    player: ContractAddress,
    player_token: felt252,
    player_combatant: felt252,
    opponent_combatant: felt252,
    opponent_token: felt252,
    round: u32,
    phase: PVEPhase,
}


/// Instance of challenge of PVEChallenge
/// PVEChallengeAttempt represents a player's attempt at completing a PVE challenge
///
/// # Fields
/// * `id` - Unique identifier for this challenge attempt
/// * `challenge` - The identifier of the PVE challenge being attempted
/// * `player` - The player's contract address
/// * `token` - The token identifier for the player's combatant
/// * `stats` - The current stats of the player during this attempt
/// * `attacks` - Array of attack moves performed by the player
/// * `expiry` - Timestamp of when the challenge attempt expires
/// * `stage` - Current stage number in the challenge
/// * `respawns` - Number of times the player has respawned
/// * `phase` - Current phase of the PVE challenge
#[dojo::model]
#[derive(Drop, Serde)]
struct PVEChallengeAttempt {
    #[key]
    id: felt252,
    challenge: felt252,
    player: ContractAddress,
    token: felt252,
    stats: UStats,
    attacks: Array<felt252>,
    expiry: u64,
    stage: u32,
    respawns: u32,
    phase: PVEPhase,
}

// Instance of PVEStageOpponent
/// Represents a PVE (Player vs Environment) stage game attempt.
///
/// # Fields
/// * `attempt_id` - A unique identifier for the game attempt
/// * `stage` - The stage number in the PVE progression
/// * `game_id` - The identifier of the associated game instance
#[dojo::model]
#[derive(Drop, Serde)]
struct PVEStageGame {
    #[key]
    attempt_id: felt252,
    #[key]
    stage: u32,
    game_id: felt252,
}

/// Event emitted when a PVE Challenge respawns
/// # Arguments
/// * `challenge_id` - The unique identifier of the PVE challenge
/// * `respawn` - The respawn number
/// * `stage` - The current stage of the challenge
/// * `game_id` - The game the player died
#[dojo::event]
#[derive(Drop, Serde)]
struct PVEChallengeRespawn {
    #[key]
    challenge_id: felt252,
    #[key]
    respawn: u32,
    stage: u32,
    game_id: felt252,
}

/// Represents the current PVE challenge status for a specific player and token
///
/// # Arguments
///
/// * `collection` - The contract address of the NFT collection
/// * `token` - The token ID within the collection
/// * `player` - The address of the player attempting the challenge
/// * `current_challenge` - The identifier of the current challenge being attempted
#[dojo::model]
#[derive(Drop, Serde)]
struct PVECurrentChallengeAttempt {
    #[key]
    player: ContractAddress,
    #[key]
    token: felt252,
    attempt_id: felt252,
}

#[derive(Drop, Serde, Introspect)]
struct PVEGameRunRound {
    player: ContractAddress,
    player_combatant: felt252,
    opponent_combatant: felt252,
    opponent_token: felt252,
    round: u32,
    phase: PVEPhase,
}

#[derive(Drop, Serde, Introspect)]
struct PVEAttemptNextStage {
    challenge: felt252,
    player: ContractAddress,
    token: felt252,
    stats: UStats,
    attacks: Array<felt252>,
    expiry: u64,
    stage: u32,
    phase: PVEPhase,
}

#[derive(Drop, Serde, Introspect)]
struct PVEAttemptRespawn {
    challenge: felt252,
    player: ContractAddress,
    token: felt252,
    stats: UStats,
    attacks: Array<felt252>,
    expiry: u64,
    stage: u32,
    phase: PVEPhase,
    respawns: u32,
}

#[derive(Drop, Serde, Introspect)]
struct PVEAttemptEnd {
    challenge: felt252,
    player: ContractAddress,
    token: felt252,
    stage: u32,
    phase: PVEPhase,
}


#[derive(Drop, Serde)]
struct PVEOpponentInput {
    name: ByteArray,
    collection: ContractAddress,
    attributes: TokenAttributes,
    stats: UStats,
    attacks: Array<IdTagNew<AttackInput>>,
    xp: u128,
    collections_allowed: Array<ContractAddress>,
}

#[derive(Drop, Serde, Introspect)]
struct PVEGameCombatantPhase {
    combatant_id: felt252,
    phase: PVEPhase,
}

#[derive(Drop)]
struct PVEStore {
    ba: WorldStorage,
    pve: WorldStorage,
}


/// PVE gameplay components that track the number of available games for a player
///
/// # Component: PVEFreeGames
/// Tracks the number of free games available to a player and when they last claimed them
/// * player - Player's contract address (primary key)
/// * games - Number of free games available
/// * last_claim - Timestamp of last claim in seconds
///
/// # Component: PVEPaidGames
/// Tracks the number of paid games available to a player
/// * player - Player's contract address (primary key)
/// * games - Number of paid games available
#[dojo::model]
#[derive(Drop, Serde)]
struct PVEFreeGames {
    #[key]
    player: ContractAddress,
    games: u32,
    last_claim: u64,
}

#[dojo::model]
#[derive(Drop, Serde)]
struct PVEPaidGames {
    #[key]
    player: ContractAddress,
    games: u32,
}

#[generate_trait]
impl PVEStorageImpl of PVEStorage {
    fn new_pve_game_model(
        ref self: WorldStorage,
        game_id: felt252,
        player: ContractAddress,
        player_token: felt252,
        player_combatant: felt252,
        opponent_token: felt252,
        opponent_combatant: felt252,
    ) -> PVEGame {
        let game = PVEGame {
            id: game_id,
            player,
            player_token,
            player_combatant,
            opponent_token,
            opponent_combatant,
            round: 1,
            phase: PVEPhase::Active,
        };
        self.write_model(@game);
        game
    }
    fn get_pve_game(self: @WorldStorage, game_id: felt252) -> PVEGame {
        self.read_model(game_id)
    }
    fn get_pve_game_run_round(self: @WorldStorage, game_id: felt252) -> PVEGameRunRound {
        self.read_schema(Model::<PVEGame>::ptr_from_keys(game_id))
    }
    fn set_pve_opponent(
        ref self: WorldStorage, id: felt252, stats: UStats, attacks: Array<felt252>, xp: u128,
    ) {
        self.write_model(@PVEOpponent { id, stats, attacks, xp });
    }
    fn check_pve_opponent_exists(self: @WorldStorage, id: felt252) -> bool {
        let value: u32 = self
            .read_member(Model::<PVEOpponent>::ptr_from_keys(id), selector!("attacks"));
        value.is_non_zero()
    }

    fn set_pve_opponents(ref self: WorldStorage, opponents: Array<@PVEOpponent>) {
        self.write_models(opponents.span());
    }

    fn set_pve_blobert_info(
        ref self: WorldStorage,
        id: felt252,
        name: ByteArray,
        collection: ContractAddress,
        attributes: TokenAttributes,
    ) {
        self.emit_event(@PVEBlobertInfo { id, name, collection, attributes });
    }

    fn set_pve_round(ref self: WorldStorage, id: felt252, round: u32) {
        self.write_member(Model::<PVEGame>::ptr_from_keys(id), selector!("round"), round);
    }

    fn set_pve_ended(ref self: WorldStorage, id: felt252, win: bool) {
        self.write_member(Model::<PVEGame>::ptr_from_keys(id), selector!("phase"), end_phase(win));
    }
    fn get_pve_opponent_attacks(self: @WorldStorage, opponent_token: felt252) -> Array<felt252> {
        self.read_member(Model::<PVEOpponent>::ptr_from_keys(opponent_token), selector!("attacks"))
    }
    fn get_pve_opponent_stats(self: @WorldStorage, opponent_token: felt252) -> UStats {
        self.read_member(Model::<PVEOpponent>::ptr_from_keys(opponent_token), selector!("stats"))
    }
    fn get_pve_game_phase(self: @WorldStorage, game_id: felt252) -> PVEPhase {
        self.read_member(Model::<PVEGame>::ptr_from_keys(game_id), selector!("phase"))
    }

    fn get_pve_game_schema<T, +Introspect<T>, +Serde<T>>(
        self: @WorldStorage, game_id: felt252,
    ) -> T {
        self.read_schema(Model::<PVEGame>::ptr_from_keys(game_id))
    }

    fn get_pve_game_combatant_phase(self: @WorldStorage, game_id: felt252) -> (felt252, PVEPhase) {
        let PVEGameCombatantPhase { combatant_id, phase } = self.get_pve_game_schema(game_id);
        (combatant_id, phase)
    }


    fn get_collection_allowed(
        self: @WorldStorage, id: felt252, collection: ContractAddress,
    ) -> bool {
        self
            .read_member(
                Model::<PVECollectionAllowed>::ptr_from_keys((id, collection)),
                selector!("allowed"),
            )
    }

    fn set_collection_allowed(
        ref self: WorldStorage, id: felt252, collection: ContractAddress, allowed: bool,
    ) {
        self.write_model(@PVECollectionAllowed { id, collection, allowed });
    }
    fn set_collections_allowed(
        ref self: WorldStorage, id: felt252, collections: Array<ContractAddress>, allowed: bool,
    ) {
        let mut models = ArrayTrait::<@PVECollectionAllowed>::new();
        for collection in collections {
            models.append(@PVECollectionAllowed { id, collection, allowed });
        };
        self.write_models(models.span());
    }
    fn set_multiple_collection_allowed(
        ref self: WorldStorage, ids: Array<felt252>, collection: ContractAddress, allowed: bool,
    ) {
        let mut models = ArrayTrait::<@PVECollectionAllowed>::new();
        for id in ids {
            models.append(@PVECollectionAllowed { id, collection, allowed });
        };
        self.write_models(models.span());
    }
    fn get_pve_challenge_health_recovery(self: @WorldStorage, id: felt252) -> u8 {
        self.read_member(Model::<PVEChallenge>::ptr_from_keys(id), selector!("health_recovery"))
    }

    fn set_pve_challenge(ref self: WorldStorage, id: felt252, health_recovery: u8) {
        self.write_model(@PVEChallenge { id, health_recovery });
    }
    fn emit_pve_challenge_name(ref self: WorldStorage, id: felt252, name: ByteArray) {
        self.emit_event(@PVEChallengeName { id, name });
    }
    fn get_pve_challenge(self: @WorldStorage, id: felt252) -> PVEChallenge {
        self.read_model(id)
    }

    fn get_pve_stage_opponent(self: @WorldStorage, challenge_id: felt252, round: u32) -> felt252 {
        self
            .read_member(
                Model::<PVEStageOpponent>::ptr_from_keys((challenge_id, round)),
                selector!("opponent"),
            )
    }
    fn set_pve_stage_opponent(
        ref self: WorldStorage, challenge_id: felt252, round: u32, opponent: felt252,
    ) {
        self.write_model(@PVEStageOpponent { challenge_id, stage: round, opponent });
    }
    fn new_pve_challenge_attempt(
        ref self: WorldStorage,
        id: felt252,
        challenge: felt252,
        player: ContractAddress,
        token: felt252,
        stats: UStats,
        attacks: Array<felt252>,
    ) -> PVEChallengeAttempt {
        let model = PVEChallengeAttempt {
            id,
            challenge,
            player,
            token,
            stats,
            attacks,
            stage: 0,
            respawns: 0,
            phase: PVEPhase::Active,
            expiry: get_block_timestamp() + ARCADE_CHALLENGE_TIME_LIMIT,
        };
        self.write_model(@model);
        model
    }
    fn set_pve_challenge_respawns(ref self: WorldStorage, id: felt252, respawns: u32) {
        self
            .write_member(
                Model::<PVEChallengeAttempt>::ptr_from_keys(id), selector!("respawns"), respawns,
            );
    }
    fn get_pve_challenge_attempt(self: @WorldStorage, id: felt252) -> PVEChallengeAttempt {
        self.read_model(id)
    }


    fn get_pve_challenge_attempt_schema<T, +Introspect<T>, +Serde<T>>(
        self: @WorldStorage, id: felt252,
    ) -> T {
        self.read_schema(Model::<PVEChallengeAttempt>::ptr_from_keys(id))
    }
    fn get_pve_challenge_attempt_next_stage(
        self: @WorldStorage, id: felt252,
    ) -> PVEAttemptNextStage {
        self.get_pve_challenge_attempt_schema(id)
    }
    fn get_pve_challenge_attempt_respawn(self: @WorldStorage, id: felt252) -> PVEAttemptRespawn {
        self.get_pve_challenge_attempt_schema(id)
    }
    fn get_pve_challenge_attempt_end_schema(self: @WorldStorage, id: felt252) -> PVEAttemptEnd {
        self.get_pve_challenge_attempt_schema(id)
    }

    fn set_pve_stage_game(
        ref self: WorldStorage, attempt_id: felt252, stage: u32, game_id: felt252,
    ) {
        self.write_model(@PVEStageGame { attempt_id, stage, game_id });
    }
    fn get_pve_stage_game_id(self: @WorldStorage, attempt_id: felt252, stage: u32) -> felt252 {
        self
            .read_member(
                Model::<PVEStageGame>::ptr_from_keys((attempt_id, stage)), selector!("game_id"),
            )
    }

    fn set_pve_challenge_stage(ref self: WorldStorage, attempt_id: felt252, stage: u32) {
        self
            .write_member(
                Model::<PVEChallengeAttempt>::ptr_from_keys(attempt_id), selector!("stage"), stage,
            );
    }
    fn set_pve_challenge_attempt_ended(ref self: WorldStorage, id: felt252, won: bool) {
        self
            .write_member(
                Model::<PVEChallengeAttempt>::ptr_from_keys(id), selector!("phase"), end_phase(won),
            );
    }

    fn set_free_games_model(ref self: WorldStorage, model: PVEFreeGames) {
        self.write_model(@model);
    }
    fn set_free_games(
        ref self: WorldStorage, player: ContractAddress, games: u32, last_claim: u64,
    ) {
        self.write_model(@PVEFreeGames { player, games, last_claim: get_block_timestamp() });
    }

    fn get_free_games(self: @WorldStorage, player: ContractAddress) -> PVEFreeGames {
        self.read_model(player)
    }

    fn get_number_of_free_games(self: @WorldStorage, player: ContractAddress) -> u32 {
        self.read_member(Model::<PVEFreeGames>::ptr_from_keys(player), selector!("games"))
    }

    fn set_number_of_free_games(ref self: WorldStorage, player: ContractAddress, games: u32) {
        self.write_member(Model::<PVEFreeGames>::ptr_from_keys(player), selector!("games"), games);
    }

    fn set_number_of_paid_games(ref self: WorldStorage, player: ContractAddress, games: u32) {
        self.write_model(@PVEPaidGames { player, games });
    }

    fn get_number_of_paid_games(self: @WorldStorage, player: ContractAddress) -> u32 {
        self.read_member(Model::<PVEPaidGames>::ptr_from_keys(player), selector!("games"))
    }

    fn emit_pve_respawn(
        ref self: WorldStorage, attempt_id: felt252, respawns: u32, stage: u32, game_id: felt252,
    ) {
        self
            .emit_event(
                @PVEChallengeRespawn {
                    challenge_id: attempt_id, respawn: respawns, stage: stage, game_id,
                },
            );
    }

    fn get_pve_current_challenge_attempt(
        self: @WorldStorage, player: ContractAddress, token: felt252,
    ) -> felt252 {
        self
            .read_member(
                Model::<PVECurrentChallengeAttempt>::ptr_from_keys((player, token)),
                selector!("current_challenge"),
            )
    }

    fn set_pve_current_challenge_attempt(
        ref self: WorldStorage, player: ContractAddress, token: felt252, attempt_id: felt252,
    ) {
        self.write_model(@PVECurrentChallengeAttempt { token, player, attempt_id });
    }

    fn remove_pve_current_challenge_attempt(
        ref self: WorldStorage, player: ContractAddress, token: felt252,
    ) {
        self.set_pve_current_challenge_attempt(player, token, 0);
    }
}
