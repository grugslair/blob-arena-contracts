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

const ARCADE_NAMESPACE_HASH: felt252 = bytearray_hash!("arcade");
const OPPONENT_TAG_GROUP: felt252 = 'arcade-opponent';
const CHALLENGE_TAG_GROUP: felt252 = 'arcade-challenge';
const ARCADE_CHALLENGE_TIME_LIMIT: u64 = 60 * 60 * 2; // 2 hours
const ARCADE_CHALLENGE_MAX_RESPAWNS: u32 = 3;
const ARCADE_CHALLENGE_GAME_ENERGY_COST: u64 = 60 * 60 * 12; // 12 hours
const ARCADE_CHALLENGE_MAX_ENERGY: u64 = 60 * 60 * 24; // 24 hours

#[derive(Drop, Copy, Introspect, PartialEq, Serde)]
enum ArcadePhase {
    None,
    Active,
    PlayerWon,
    PlayerLost,
}

fn end_phase(won: bool) -> ArcadePhase {
    match won {
        true => ArcadePhase::PlayerWon,
        false => ArcadePhase::PlayerLost,
    }
}

#[generate_trait]
impl ArcadePhaseImpl of ArcadePhaseTrait {
    fn assert_active(self: ArcadePhase) {
        assert(self == ArcadePhase::Active, 'Phase not active');
    }
}

///////////////// Setup models

/// A model representing a Arcade (Player vs Environment) opponent in the game
///
/// # Fields
/// * `id` - Unique Id of the opponent as a field element
/// * `stats` - Starting stats of the opponent using the UStats structure
/// * `attacks` - Array of attack IDs available to this opponent as field elements
#[dojo::model]
#[derive(Drop, Serde)]
struct ArcadeOpponent {
    #[key]
    id: felt252,
    stats: UStats,
    attacks: Array<felt252>,
}

/// Event emitted when for a arcade blobert for off chain use only
/// # Arguments
/// * `id` - Unique Id for the blobert
/// * `name` - The name of the blobert
/// * `collection` - The contract address of the collection the blobert belongs to
/// * `attributes` - The attributes of the blobert token
#[dojo::event]
#[derive(Drop, Serde)]
struct ArcadeBlobertInfo {
    #[key]
    id: felt252,
    name: ByteArray,
    collection: ContractAddress,
    attributes: TokenAttributes,
}

/// Records a Arcade Challenge within the game, identified by a unique ID.
///
/// # Arguments
/// * `id` - A unique Id for the Arcade challenge
/// * `health_recovery` - Amount of health recovered after each round as a percentage of max health
#[dojo::model]
#[derive(Drop, Serde)]
struct ArcadeChallenge {
    #[key]
    id: felt252,
    health_recovery: u8,
}

/// Event emitted when a Arcade challenge name is set
/// # Arguments
/// * `id` - The unique Id of the Arcade challenge
/// * `name` - The name of the Arcade challenge as a ByteArray
#[dojo::event]
#[derive(Drop, Serde)]
struct ArcadeChallengeName {
    #[key]
    id: felt252,
    name: ByteArray,
}

/// A model representing an opponent in a specific stage of a Arcade challenge
///
/// # Fields
/// * `challenge_id` - Id for the Arcade challenge
/// * `stage` - Stage number within the challenge
/// * `opponent` - Id of the opponent at this stage
#[dojo::model]
#[derive(Drop, Serde)]
struct ArcadeStageOpponent {
    #[key]
    challenge_id: felt252,
    #[key]
    stage: u32,
    opponent: felt252,
}

/// Represents a permission model for Arcade (Player vs Environment) collections
///
/// # Arguments
/// * `id` - A unique identifier for the permission entry (Challenge or opponent id)
/// * `collection` - The contract address of the collection
/// * `allowed` - A boolean flag indicating whether the collection is allowed in Arcade
///
/// This model is used to manage which NFT collections are permitted to participate
/// in Arcade gameplay scenarios
#[dojo::model]
#[derive(Drop, Serde)]
struct ArcadeCollectionAllowed {
    #[key]
    id: felt252,
    #[key]
    collection: ContractAddress,
    allowed: bool,
}

//////////////////// Game Models

/// Instance of combat against ArcadeOpponent
/// A ArcadeGame represents a player versus environment game instance
///
/// # Arguments
/// * `id` - Unique identifier for the game instance
/// * `combatant_id` - Identifier for the player's combatant
/// * `player` - Contract address of the player
/// * `opponent_token` - Token identifier for the opponent
/// * `opponent_id` - Identifier for the opponent combatant
/// * `round` - Current round number of the game
/// * `phase` - Current phase of the game
#[dojo::model]
#[derive(Drop, Serde)]
struct ArcadeGame {
    #[key]
    id: felt252,
    combatant_id: felt252,
    player: ContractAddress,
    opponent_token: felt252,
    opponent_id: felt252,
    round: u32,
    phase: ArcadePhase,
}


/// Instance of challenge of ArcadeChallenge
/// ArcadeChallengeAttempt represents a player's attempt at completing a Arcade challenge
///
/// # Fields
/// * `id` - Unique identifier for this challenge attempt
/// * `challenge` - The identifier of the Arcade challenge being attempted
/// * `player` - The player's contract address
/// * `collection` - The contract address of the NFT collection
/// * `token_id` - The token ID of the NFT being used
/// * `stats` - The current stats of the player during this attempt
/// * `attacks` - Array of attack moves performed by the player
/// * `expiry` - Timestamp of when the challenge attempt expires
/// * `stage` - Current stage number in the challenge
/// * `respawns` - Number of times the player has respawned
/// * `phase` - Current phase of the Arcade challenge
#[dojo::model]
#[derive(Drop, Serde)]
struct ArcadeChallengeAttempt {
    #[key]
    id: felt252,
    challenge: felt252,
    player: ContractAddress,
    collection: ContractAddress,
    token_id: u256,
    stats: UStats,
    attacks: Array<felt252>,
    expiry: u64,
    stage: u32,
    respawns: u32,
    phase: ArcadePhase,
}

// Instance of ArcadeStageOpponent
/// Represents a Arcade (Player vs Environment) stage game attempt.
///
/// # Fields
/// * `attempt_id` - A unique identifier for the game attempt
/// * `stage` - The stage number in the Arcade progression
/// * `game_id` - The identifier of the associated game instance
#[dojo::model]
#[derive(Drop, Serde)]
struct ArcadeStageGame {
    #[key]
    attempt_id: felt252,
    #[key]
    stage: u32,
    game_id: felt252,
}

/// Event emitted when a Arcade Challenge respawns
/// # Arguments
/// * `challenge_id` - The unique identifier of the Arcade challenge
/// * `respawn` - The respawn number
/// * `stage` - The current stage of the challenge
/// * `game_id` - The game the player died
#[dojo::event]
#[derive(Drop, Serde)]
struct ArcadeChallengeRespawn {
    #[key]
    challenge_id: felt252,
    #[key]
    respawn: u32,
    stage: u32,
    game_id: felt252,
}

/// Represents the current Arcade challenge status for a specific player and token
///
/// # Arguments
///
/// * `collection` - The contract address of the NFT collection
/// * `token` - The token ID within the collection
/// * `player` - The address of the player attempting the challenge
/// * `current_challenge` - The identifier of the current challenge being attempted
#[dojo::model]
#[derive(Drop, Serde)]
struct ArcadeCurrentChallengeAttempt {
    #[key]
    player: ContractAddress,
    #[key]
    collection: ContractAddress,
    #[key]
    token_id: u256,
    attempt_id: felt252,
}

#[derive(Drop, Serde, Introspect)]
struct ArcadeAttemptNextStage {
    challenge: felt252,
    player: ContractAddress,
    stats: UStats,
    attacks: Array<felt252>,
    expiry: u64,
    stage: u32,
    phase: ArcadePhase,
}

#[derive(Drop, Serde, Introspect)]
struct ArcadeAttemptRespawn {
    challenge: felt252,
    player: ContractAddress,
    stats: UStats,
    attacks: Array<felt252>,
    expiry: u64,
    stage: u32,
    phase: ArcadePhase,
    respawns: u32,
}

#[derive(Drop, Serde, Introspect)]
struct ArcadeAttemptEnd {
    challenge: felt252,
    player: ContractAddress,
    collection: ContractAddress,
    token_id: u256,
    stage: u32,
    phase: ArcadePhase,
    respawns: u32,
}


#[derive(Drop, Serde)]
struct ArcadeOpponentInput {
    name: ByteArray,
    collection: ContractAddress,
    attributes: TokenAttributes,
    stats: UStats,
    attacks: Array<IdTagNew<AttackInput>>,
}

#[derive(Drop, Serde, Introspect)]
struct ArcadeGameCombatantPhase {
    combatant_id: felt252,
    phase: ArcadePhase,
}

#[derive(Drop)]
struct ArcadeStore {
    ba: WorldStorage,
    arcade: WorldStorage,
}

#[derive(Drop, Serde, Introspect)]
struct ArcadeAttemptGetGame {
    challenge: felt252,
    stage: u32,
}


/// Arcade gameplay components that track the number of available games for a player
///
/// # Component: ArcadeFreeGames
/// Tracks the number of free games available to a player and when they last claimed them
/// * player - Player's contract address (primary key)
/// * games - Number of free games available
/// * last_claim - Timestamp of last claim in seconds
///
/// # Component: ArcadePaidGames
/// Tracks the number of paid games available to a player
/// * player - Player's contract address (primary key)
/// * games - Number of paid games available
#[dojo::model]
#[derive(Drop, Serde)]
struct ArcadeFreeGames {
    #[key]
    player: ContractAddress,
    energy: u64,
    timestamp: u64,
}

#[dojo::model]
#[derive(Drop, Serde)]
struct ArcadePaidGames {
    #[key]
    player: ContractAddress,
    games: u32,
}

#[generate_trait]
impl ArcadeStorageImpl of ArcadeStorage {
    fn new_arcade_game_model(
        ref self: WorldStorage,
        game_id: felt252,
        combatant_id: felt252,
        player: ContractAddress,
        opponent_token: felt252,
        opponent_id: felt252,
    ) -> ArcadeGame {
        let game = ArcadeGame {
            id: game_id,
            combatant_id,
            player,
            opponent_token,
            opponent_id,
            round: 1,
            phase: ArcadePhase::Active,
        };
        self.write_model(@game);
        game
    }
    fn get_arcade_game(self: @WorldStorage, game_id: felt252) -> ArcadeGame {
        self.read_model(game_id)
    }
    fn set_arcade_opponent(
        ref self: WorldStorage, id: felt252, stats: UStats, attacks: Array<felt252>,
    ) {
        self.write_model(@ArcadeOpponent { id, stats, attacks });
    }
    fn check_arcade_opponent_exists(self: @WorldStorage, id: felt252) -> bool {
        let value: u32 = self
            .read_member(Model::<ArcadeOpponent>::ptr_from_keys(id), selector!("attacks"));
        value.is_non_zero()
    }

    fn set_arcade_opponents(ref self: WorldStorage, opponents: Array<@ArcadeOpponent>) {
        self.write_models(opponents.span());
    }

    fn set_arcade_info(
        ref self: WorldStorage,
        id: felt252,
        name: ByteArray,
        collection: ContractAddress,
        attributes: TokenAttributes,
    ) {
        self.emit_event(@ArcadeBlobertInfo { id, name, collection, attributes });
    }

    fn set_arcade_round(ref self: WorldStorage, id: felt252, round: u32) {
        self.write_member(Model::<ArcadeGame>::ptr_from_keys(id), selector!("round"), round);
    }

    fn set_arcade_ended(ref self: WorldStorage, id: felt252, win: bool) {
        self
            .write_member(
                Model::<ArcadeGame>::ptr_from_keys(id), selector!("phase"), end_phase(win),
            );
    }

    fn get_arcade_opponent(self: @WorldStorage, opponent_token: felt252) -> ArcadeOpponent {
        self.read_model(opponent_token)
    }
    fn get_arcade_opponent_attacks(self: @WorldStorage, opponent_token: felt252) -> Array<felt252> {
        self
            .read_member(
                Model::<ArcadeOpponent>::ptr_from_keys(opponent_token), selector!("attacks"),
            )
    }
    fn get_arcade_opponent_stats(self: @WorldStorage, opponent_token: felt252) -> UStats {
        self.read_member(Model::<ArcadeOpponent>::ptr_from_keys(opponent_token), selector!("stats"))
    }
    fn get_arcade_game_phase(self: @WorldStorage, game_id: felt252) -> ArcadePhase {
        self.read_member(Model::<ArcadeGame>::ptr_from_keys(game_id), selector!("phase"))
    }

    fn get_arcade_game_schema<T, +Introspect<T>, +Serde<T>>(
        self: @WorldStorage, game_id: felt252,
    ) -> T {
        self.read_schema(Model::<ArcadeGame>::ptr_from_keys(game_id))
    }

    fn get_arcade_game_combatant_phase(
        self: @WorldStorage, game_id: felt252,
    ) -> (felt252, ArcadePhase) {
        let ArcadeGameCombatantPhase { combatant_id, phase } = self.get_arcade_game_schema(game_id);
        (combatant_id, phase)
    }


    fn get_collection_allowed(
        self: @WorldStorage, id: felt252, collection: ContractAddress,
    ) -> bool {
        self
            .read_member(
                Model::<ArcadeCollectionAllowed>::ptr_from_keys((id, collection)),
                selector!("allowed"),
            )
    }

    fn set_collection_allowed(
        ref self: WorldStorage, id: felt252, collection: ContractAddress, allowed: bool,
    ) {
        self.write_model(@ArcadeCollectionAllowed { id, collection, allowed });
    }
    fn set_collections_allowed(
        ref self: WorldStorage, id: felt252, collections: Array<ContractAddress>, allowed: bool,
    ) {
        let mut models = ArrayTrait::<@ArcadeCollectionAllowed>::new();
        for collection in collections {
            models.append(@ArcadeCollectionAllowed { id, collection, allowed });
        };
        self.write_models(models.span());
    }
    fn set_multiple_collection_allowed(
        ref self: WorldStorage, ids: Array<felt252>, collection: ContractAddress, allowed: bool,
    ) {
        let mut models = ArrayTrait::<@ArcadeCollectionAllowed>::new();
        for id in ids {
            models.append(@ArcadeCollectionAllowed { id, collection, allowed });
        };
        self.write_models(models.span());
    }
    fn get_arcade_challenge_health_recovery(self: @WorldStorage, id: felt252) -> u8 {
        self.read_member(Model::<ArcadeChallenge>::ptr_from_keys(id), selector!("health_recovery"))
    }

    fn set_arcade_challenge(ref self: WorldStorage, id: felt252, health_recovery: u8) {
        self.write_model(@ArcadeChallenge { id, health_recovery });
    }
    fn emit_arcade_challenge_name(ref self: WorldStorage, id: felt252, name: ByteArray) {
        self.emit_event(@ArcadeChallengeName { id, name });
    }
    fn get_arcade_challenge(self: @WorldStorage, id: felt252) -> ArcadeChallenge {
        self.read_model(id)
    }

    fn get_arcade_stage_opponent(
        self: @WorldStorage, challenge_id: felt252, round: u32,
    ) -> felt252 {
        self
            .read_member(
                Model::<ArcadeStageOpponent>::ptr_from_keys((challenge_id, round)),
                selector!("opponent"),
            )
    }
    fn set_arcade_stage_opponent(
        ref self: WorldStorage, challenge_id: felt252, round: u32, opponent: felt252,
    ) {
        self.write_model(@ArcadeStageOpponent { challenge_id, stage: round, opponent });
    }
    fn new_arcade_challenge_attempt(
        ref self: WorldStorage,
        id: felt252,
        challenge: felt252,
        player: ContractAddress,
        collection: ContractAddress,
        token_id: u256,
        stats: UStats,
        attacks: Array<felt252>,
        timestamp: u64,
    ) -> ArcadeChallengeAttempt {
        let model = ArcadeChallengeAttempt {
            id,
            challenge,
            player,
            collection,
            token_id,
            stats,
            attacks,
            stage: 0,
            respawns: 0,
            phase: ArcadePhase::Active,
            expiry: timestamp + ARCADE_CHALLENGE_TIME_LIMIT,
        };
        self.write_model(@model);
        model
    }
    fn set_arcade_challenge_respawns(ref self: WorldStorage, id: felt252, respawns: u32) {
        self
            .write_member(
                Model::<ArcadeChallengeAttempt>::ptr_from_keys(id), selector!("respawns"), respawns,
            );
    }
    fn get_arcade_challenge_attempt(self: @WorldStorage, id: felt252) -> ArcadeChallengeAttempt {
        self.read_model(id)
    }


    fn get_arcade_challenge_attempt_schema<T, +Introspect<T>, +Serde<T>>(
        self: @WorldStorage, id: felt252,
    ) -> T {
        self.read_schema(Model::<ArcadeChallengeAttempt>::ptr_from_keys(id))
    }
    fn get_arcade_challenge_attempt_next_stage(
        self: @WorldStorage, id: felt252,
    ) -> ArcadeAttemptNextStage {
        self.get_arcade_challenge_attempt_schema(id)
    }
    fn get_arcade_challenge_attempt_respawn(
        self: @WorldStorage, id: felt252,
    ) -> ArcadeAttemptRespawn {
        self.get_arcade_challenge_attempt_schema(id)
    }
    fn get_arcade_challenge_attempt_end_schema(
        self: @WorldStorage, id: felt252,
    ) -> ArcadeAttemptEnd {
        self.get_arcade_challenge_attempt_schema(id)
    }

    fn set_arcade_stage_game(
        ref self: WorldStorage, attempt_id: felt252, stage: u32, game_id: felt252,
    ) {
        self.write_model(@ArcadeStageGame { attempt_id, stage, game_id });
    }
    fn get_arcade_stage_game_id(self: @WorldStorage, attempt_id: felt252, stage: u32) -> felt252 {
        self
            .read_member(
                Model::<ArcadeStageGame>::ptr_from_keys((attempt_id, stage)), selector!("game_id"),
            )
    }

    fn set_arcade_challenge_stage(ref self: WorldStorage, attempt_id: felt252, stage: u32) {
        self
            .write_member(
                Model::<ArcadeChallengeAttempt>::ptr_from_keys(attempt_id),
                selector!("stage"),
                stage,
            );
    }
    fn get_arcade_challenge_stage(
        self: @WorldStorage, attempt_id: felt252,
    ) -> ArcadeAttemptGetGame {
        self.get_arcade_challenge_attempt_schema(attempt_id)
    }
    fn set_arcade_challenge_attempt_ended(ref self: WorldStorage, id: felt252, won: bool) {
        self
            .write_member(
                Model::<ArcadeChallengeAttempt>::ptr_from_keys(id),
                selector!("phase"),
                end_phase(won),
            );
    }
    fn set_free_games(
        ref self: WorldStorage, player: ContractAddress, energy: u64, timestamp: u64,
    ) {
        self.write_model(@ArcadeFreeGames { player, energy, timestamp });
    }

    fn get_free_games(self: @WorldStorage, player: ContractAddress) -> ArcadeFreeGames {
        self.read_model(player)
    }


    fn set_number_of_paid_games(ref self: WorldStorage, player: ContractAddress, games: u32) {
        self.write_model(@ArcadePaidGames { player, games });
    }

    fn get_number_of_paid_games(self: @WorldStorage, player: ContractAddress) -> u32 {
        self.read_member(Model::<ArcadePaidGames>::ptr_from_keys(player), selector!("games"))
    }

    fn emit_arcade_respawn(
        ref self: WorldStorage, attempt_id: felt252, respawns: u32, stage: u32, game_id: felt252,
    ) {
        self
            .emit_event(
                @ArcadeChallengeRespawn {
                    challenge_id: attempt_id, respawn: respawns, stage: stage, game_id,
                },
            );
    }

    fn get_arcade_current_challenge_attempt(
        self: @WorldStorage, player: ContractAddress, collection: ContractAddress, token_id: u256,
    ) -> felt252 {
        self
            .read_member(
                Model::<
                    ArcadeCurrentChallengeAttempt,
                >::ptr_from_keys((player, collection, token_id)),
                selector!("attempt_id"),
            )
    }

    fn set_arcade_current_challenge_attempt(
        ref self: WorldStorage,
        player: ContractAddress,
        collection: ContractAddress,
        token_id: u256,
        attempt_id: felt252,
    ) {
        self
            .write_model(
                @ArcadeCurrentChallengeAttempt { collection, token_id, player, attempt_id },
            );
    }

    fn remove_arcade_current_challenge_attempt(
        ref self: WorldStorage,
        player: ContractAddress,
        collection: ContractAddress,
        token_id: u256,
    ) {
        self.set_arcade_current_challenge_attempt(player, collection, token_id, 0);
    }
}
