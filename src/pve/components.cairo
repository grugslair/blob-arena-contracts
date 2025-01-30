use dojo::model::ModelValueStorage;
use starknet::ContractAddress;
use dojo::{world::WorldStorage, model::{ModelStorage, Model}, event::EventStorage};
use blob_arena::{stats::UStats, collections::blobert::TokenAttributes};

#[derive(Drop, Serde, Copy, Introspect, PartialEq)]
enum PVEPhase {
    None,
    Active,
    Ended: bool,
}

fn pve_namespace() -> @ByteArray {
    @"pve_blobert"
}

#[dojo::model]
#[derive(Drop, Serde)]
struct PVEOpponent {
    #[key]
    id: felt252,
    stats: UStats,
    attacks: Array<felt252>,
}

#[dojo::model]
#[derive(Drop, Serde)]
struct PVECollectionAllowed {
    #[key]
    token_id: felt252,
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
    player: ContractAddress,
    player_id: felt252,
    opponent_token: felt252,
    opponent_id: felt252,
    round: u32,
    phase: PVEPhase,
}

#[dojo::model]
#[derive(Drop, Serde)]
struct PVEChallengeSetup {
    #[key]
    id: felt252,
    health_recovery: u8,
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
struct PVEChallenge {
    #[key]
    id: felt252,
    stages: felt252,
    player: ContractAddress,
    combatant_id: felt252,
    stats: UStats,
    attacks: Array<felt252>,
    stage: u32,
}

#[dojo::model]
#[derive(Drop, Serde)]
struct PVEStageGame {
    #[key]
    challenge_id: felt252,
    #[key]
    stage: u32,
    game_id: felt252,
}

#[derive(Drop, Copy)]
struct PVEStore {
    ba: WorldStorage,
    pve: WorldStorage,
}


#[generate_trait]
impl PVEStorageImpl of PVEStorage {
    fn new_pve_game_model(
        ref self: WorldStorage,
        game_id: felt252,
        player: ContractAddress,
        player_id: felt252,
        opponent_token: felt252,
        opponent_id: felt252,
    ) -> PVEGame {
        let game = PVEGame {
            id: game_id,
            player,
            player_id,
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
        self
            .write_member(
                Model::<PVEGame>::ptr_from_keys(id), selector!("phase"), PVEPhase::Ended(win),
            );
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

    fn get_collection_allowed(
        self: @WorldStorage, token_id: felt252, collection: ContractAddress,
    ) -> bool {
        let value: PVECollectionAllowedValue = self.read_value((token_id, collection));
        value.allowed
    }

    fn set_collection_allowed(
        ref self: WorldStorage, token_id: felt252, collection: ContractAddress, allowed: bool,
    ) {
        self.write_model(@PVECollectionAllowed { token_id, collection, allowed });
    }
    fn set_collections_allowed(
        ref self: WorldStorage,
        token_id: felt252,
        collections: Array<ContractAddress>,
        allowed: bool,
    ) {
        let mut models = ArrayTrait::<@PVECollectionAllowed>::new();
        for collection in collections {
            models.append(@PVECollectionAllowed { token_id, collection, allowed });
        };
        self.write_models(models.span());
    }
    fn set_mutiple_collection_allowed(
        ref self: WorldStorage,
        token_ids: Array<felt252>,
        collection: ContractAddress,
        allowed: bool,
    ) {
        let mut models = ArrayTrait::<@PVECollectionAllowed>::new();
        for token_id in token_ids {
            models.append(@PVECollectionAllowed { token_id, collection, allowed });
        };
        self.write_models(models.span());
    }
    fn get_pve_challenge_health_recovery(self: @WorldStorage, id: felt252) -> u8 {
        self
            .read_member(
                Model::<PVEChallengeSetup>::ptr_from_keys(id), selector!("health_recovery"),
            )
    }
    fn get_pve_challenge_rounds(self: @WorldStorage, id: felt252) -> PVEChallengeSetup {
        self.read_model(id)
    }

    fn get_pve_stage_opponent(self: @WorldStorage, challenge_id: felt252, round: u32) -> felt252 {
        self
            .read_member(
                Model::<PVEStageOpponent>::ptr_from_keys(challenge_id), selector!("opponent"),
            )
    }
    fn new_pve_challenge(
        ref self: WorldStorage,
        id: felt252,
        stages: felt252,
        player: ContractAddress,
        combatant_id: felt252,
        stats: UStats,
        attacks: Array<felt252>,
    ) {
        self
            .write_model(
                @PVEChallenge { id, stages, player, combatant_id, stats, attacks, stage: 1 },
            );
    }
    fn get_pve_challenge(self: @WorldStorage, id: felt252) -> PVEChallenge {
        self.read_model(id)
    }
    fn set_pve_stage_game(
        ref self: WorldStorage, challenge_id: felt252, stage: u32, game_id: felt252,
    ) {
        self.write_model(@PVEStageGame { challenge_id, stage, game_id });
    }
    fn get_pve_stage_game_id(self: @WorldStorage, challenge_id: felt252, stage: u32) -> felt252 {
        self
            .read_member(
                Model::<PVEStageGame>::ptr_from_keys((challenge_id, stage)), selector!("game_id"),
            )
    }
    fn get_pve_stage_game_phase(
        self: @WorldStorage, challenge_id: felt252, stage: u32,
    ) -> PVEPhase {
        self.get_pve_game_phase(self.get_pve_stage_game_id(challenge_id, stage))
    }
    fn set_pve_challenge_stage(ref self: WorldStorage, challenge_id: felt252, stage: u32) {
        self
            .write_member(
                Model::<PVEChallenge>::ptr_from_keys(challenge_id), selector!("stage"), stage,
            );
    }
}
