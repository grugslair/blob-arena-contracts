use starknet::ContractAddress;
use dojo::model::{ModelStorage, Model};
use dojo::world::WorldStorage;
use dojo::meta::Introspect;

use crate::stats::UStats;
use crate::iter::Iteration;
use crate::arcade::{ArcadePhase, ArcadeGame, ArcadeStorage};
use crate::arcade::components::{ARCADE_CHALLENGE_TIME_LIMIT, end_phase, ArcadeAttemptGetGame};
use crate::world::WorldTrait;

const AMMA_ARCADE_NAMESPACE_HASH: felt252 = bytearray_hash!("arcade-amma");
const AMMA_ARCADE_GENERATED_STAGES: u32 = 9;

#[dojo::model]
#[derive(Serde, Drop)]
struct AmmaArcadeStageOpponent {
    #[key]
    attempt_id: felt252,
    #[key]
    stage: u32,
    opponent: u32,
}

#[derive(Drop, Serde, Introspect)]
struct PlayerStage {
    player: ContractAddress,
    stage: u32,
}


/// Instance of challenge of ArcadeChallenge
/// AmmaArcadeChallengeAttempt represents a player's attempt at completing a Arcade challenge
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
struct AmmaArcadeChallengeAttempt {
    #[key]
    id: felt252,
    player: ContractAddress,
    token_id: u256,
    stats: UStats,
    attacks: Array<felt252>,
    expiry: u64,
    stage: u32,
    respawns: u32,
    phase: ArcadePhase,
}

#[derive(Drop, Serde, Introspect)]
struct AmmaArcadeAttemptNextStage {
    player: ContractAddress,
    stats: UStats,
    attacks: Array<felt252>,
    expiry: u64,
    stage: u32,
    phase: ArcadePhase,
}

#[derive(Drop, Serde, Introspect)]
struct AmmaArcadeAttemptRespawn {
    player: ContractAddress,
    stats: UStats,
    attacks: Array<felt252>,
    expiry: u64,
    stage: u32,
    phase: ArcadePhase,
    respawns: u32,
}

#[derive(Drop, Serde, Introspect)]
struct AmmaArcadeAttemptEnd {
    player: ContractAddress,
    token_id: u256,
    stage: u32,
    phase: ArcadePhase,
    respawns: u32,
}

#[derive(Drop, Serde, Introspect)]
struct AmmaArcadeAttemptUnlockToken {
    player: ContractAddress,
    token_id: u256,
    phase: ArcadePhase,
}


#[generate_trait]
impl AmmaArcadeStorageImpl of AmmaArcadeStorage {
    fn set_amma_round_opponents(
        ref self: WorldStorage, attempt_id: felt252, opponents: Array<u32>,
    ) {
        let mut models: Array<@AmmaArcadeStageOpponent> = Default::default();
        for (stage, opponent) in opponents.enumerate() {
            models.append(@AmmaArcadeStageOpponent { attempt_id: attempt_id, stage, opponent });
        };
        self.write_models(models.span())
    }
    fn set_amma_round_opponent(
        ref self: WorldStorage, attempt_id: felt252, stage: u32, opponent: u32,
    ) {
        self
            .write_model(
                @AmmaArcadeStageOpponent { attempt_id: attempt_id, stage, opponent: opponent + 1 },
            )
    }
    fn get_amma_round_opponent(self: @WorldStorage, attempt_id: felt252, stage: u32) -> u32 {
        self
            .read_member(
                Model::<AmmaArcadeStageOpponent>::ptr_from_keys((attempt_id, stage)),
                selector!("opponent"),
            )
    }

    fn new_amma_arcade_challenge_attempt(
        ref self: WorldStorage,
        id: felt252,
        player: ContractAddress,
        token_id: u256,
        stats: UStats,
        attacks: Array<felt252>,
        timestamp: u64,
    ) -> AmmaArcadeChallengeAttempt {
        let model = AmmaArcadeChallengeAttempt {
            id,
            player,
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
    fn get_amma_arcade_challenge_attempt(
        self: @WorldStorage, id: felt252,
    ) -> AmmaArcadeChallengeAttempt {
        self.read_model(id)
    }

    fn get_amma_arcade_challenge_attempt_schema<T, +Introspect<T>, +Serde<T>>(
        self: @WorldStorage, id: felt252,
    ) -> T {
        self.read_schema(Model::<AmmaArcadeChallengeAttempt>::ptr_from_keys(id))
    }
    fn get_amma_arcade_challenge_attempt_next_stage(
        self: @WorldStorage, id: felt252,
    ) -> AmmaArcadeAttemptNextStage {
        self.get_amma_arcade_challenge_attempt_schema(id)
    }
    fn get_amma_arcade_challenge_attempt_respawn(
        self: @WorldStorage, id: felt252,
    ) -> AmmaArcadeAttemptRespawn {
        self.get_amma_arcade_challenge_attempt_schema(id)
    }
    fn get_amma_arcade_challenge_attempt_end(
        self: @WorldStorage, id: felt252,
    ) -> AmmaArcadeAttemptEnd {
        self.get_amma_arcade_challenge_attempt_schema(id)
    }

    fn get_amma_arcade_challenge_attempt_player_stage(
        self: @WorldStorage, id: felt252,
    ) -> PlayerStage {
        self.get_amma_arcade_challenge_attempt_schema(id)
    }

    fn get_amma_arcade_challenge_attempt_unlock_token(
        self: @WorldStorage, id: felt252,
    ) -> AmmaArcadeAttemptUnlockToken {
        self.storage(AMMA_ARCADE_NAMESPACE_HASH).get_amma_arcade_challenge_attempt_schema(id)
    }

    fn set_amma_arcade_challenge_attempt_ended(ref self: WorldStorage, id: felt252, won: bool) {
        self
            .write_member(
                Model::<AmmaArcadeChallengeAttempt>::ptr_from_keys(id),
                selector!("phase"),
                end_phase(won),
            );
    }

    fn set_amma_arcade_challenge_respawns(ref self: WorldStorage, id: felt252, respawns: u32) {
        self
            .write_member(
                Model::<AmmaArcadeChallengeAttempt>::ptr_from_keys(id),
                selector!("respawns"),
                respawns,
            );
    }

    fn set_amma_arcade_challenge_stage(ref self: WorldStorage, attempt_id: felt252, stage: u32) {
        self
            .write_member(
                Model::<AmmaArcadeChallengeAttempt>::ptr_from_keys(attempt_id),
                selector!("stage"),
                stage,
            );
    }

    fn get_amma_arcade_challenge_attempt_stage(self: @WorldStorage, attempt_id: felt252) -> u32 {
        self
            .read_member(
                Model::<AmmaArcadeChallengeAttempt>::ptr_from_keys(attempt_id), selector!("stage"),
            )
    }

    fn get_amma_arcade_attempt_game(self: @WorldStorage, attempt_id: felt252) -> ArcadeGame {
        let stage = self.get_amma_arcade_challenge_attempt_stage(attempt_id);
        self.get_arcade_game(self.get_arcade_stage_game_id(attempt_id, stage))
    }
}
