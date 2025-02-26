use dojo::model::ModelValueStorage;
use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
use dojo::{
    world::WorldStorage, model::{ModelStorage, Model}, event::EventStorage, meta::Introspect,
};
use blob_arena::{
    attacks::AttackInput, stats::UStats, collections::blobert::TokenAttributes, tags::IdTagNew,
};

const PVE_NAMESPACE_HASH: felt252 = bytearray_hash!("pve_blobert");
const OPPONENT_TAG_GROUP: felt252 = 'pve-opponent';
const CHALLENGE_TAG_GROUP: felt252 = 'pve-challenge';

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

#[dojo::model]
#[derive(Drop, Serde)]
struct PVEOpponent {
    #[key]
    id: felt252,
    stats: UStats,
    attacks: Array<felt252>,
}

#[derive(Drop, Serde)]
struct PVEOpponentInput {
    name: ByteArray,
    collection: ContractAddress,
    attributes: TokenAttributes,
    stats: UStats,
    attacks: Array<IdTagNew<AttackInput>>,
    collections_allowed: Array<ContractAddress>,
}

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

#[dojo::model]
#[derive(Drop, Serde)]
struct PVECollectionAllowed {
    #[key]
    id: felt252,
    #[key]
    collection: ContractAddress,
    allowed: bool,
}

#[dojo::event]
#[derive(Drop, Serde)]
struct PVEBlobertInfo {
    #[key]
    id: felt252,
    name: ByteArray,
    collection: ContractAddress,
    attributes: TokenAttributes,
}

#[dojo::model]
#[derive(Drop, Serde)]
struct PVEGame {
    #[key]
    id: felt252,
    combatant_id: felt252,
    player: ContractAddress,
    opponent_token: felt252,
    opponent_id: felt252,
    round: u32,
    phase: PVEPhase,
}

#[derive(Drop, Serde, Introspect)]
struct PVEGameCombatantPhase {
    combatant_id: felt252,
    phase: PVEPhase,
}

#[dojo::model]
#[derive(Drop, Serde)]
struct PVEChallenge {
    #[key]
    id: felt252,
    health_recovery: u8,
}

#[dojo::event]
#[derive(Drop, Serde)]
struct PVEChallengeName {
    #[key]
    id: felt252,
    name: ByteArray,
}

#[dojo::model]
#[derive(Drop, Serde)]
struct PVEStageOpponent {
    #[key]
    challenge_id: felt252,
    #[key]
    stage: u32,
    opponent: felt252,
}

#[dojo::model]
#[derive(Drop, Serde)]
struct PVEChallengeAttempt {
    #[key]
    id: felt252,
    challenge: felt252,
    player: ContractAddress,
    stats: UStats,
    attacks: Array<felt252>,
    stage: u32,
    respawns: u32,
    phase: PVEPhase,
}

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

#[derive(Drop, Serde, Introspect)]
struct PVEEndAttemptSchema {
    challenge: felt252,
    player: ContractAddress,
    stage: u32,
    phase: PVEPhase,
}


#[dojo::model]
#[derive(Drop, Serde)]
struct PVEStageGame {
    #[key]
    attempt_id: felt252,
    #[key]
    stage: u32,
    game_id: felt252,
}

#[derive(Drop)]
struct PVEStore {
    ba: WorldStorage,
    pve: WorldStorage,
}


#[generate_trait]
impl PVEStorageImpl of PVEStorage {
    fn new_pve_game_model(
        ref self: WorldStorage,
        game_id: felt252,
        combatant_id: felt252,
        player: ContractAddress,
        opponent_token: felt252,
        opponent_id: felt252,
    ) -> PVEGame {
        let game = PVEGame {
            id: game_id,
            combatant_id,
            player,
            opponent_token,
            opponent_id,
            round: 1,
            phase: PVEPhase::Active,
        };
        self.write_model(@game);
        game
    }
    fn get_pve_game(self: @WorldStorage, game_id: felt252) -> PVEGame {
        self.read_model(game_id)
    }
    fn set_pve_opponent(
        ref self: WorldStorage, id: felt252, stats: UStats, attacks: Array<felt252>,
    ) {
        self.write_model(@PVEOpponent { id, stats, attacks });
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
        stats: UStats,
        attacks: Array<felt252>,
    ) -> PVEChallengeAttempt {
        let model = PVEChallengeAttempt {
            id, challenge, player, stats, attacks, stage: 0, respawns: 0, phase: PVEPhase::Active,
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
    fn get_pve_challenge_attempt_end_schema(
        self: @WorldStorage, id: felt252,
    ) -> PVEEndAttemptSchema {
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

    fn emit_pve_respawn(ref self: WorldStorage, attempt: @PVEChallengeAttempt, game_id: felt252) {
        self
            .emit_event(
                @PVEChallengeRespawn {
                    challenge_id: *attempt.challenge,
                    respawn: *attempt.respawns,
                    stage: *attempt.stage,
                    game_id,
                },
            );
    }
}
