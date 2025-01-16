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
    attributes: TokenAttributes
}

#[dojo::model]
#[derive(Drop, Serde, Copy)]
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
            phase: PVEPhase::Active
        };
        self.write_model(@game);
        game
    }
    fn get_pve_game(self: @WorldStorage, game_id: felt252) -> PVEGame {
        self.read_model(game_id)
    }
    fn set_pve_opponent(
        ref self: WorldStorage, id: felt252, stats: UStats, attacks: Array<felt252>
    ) {
        self.write_model(@PVEOpponent { id, stats, attacks });
    }

    fn set_pve_blobert_info(
        ref self: WorldStorage,
        id: felt252,
        name: ByteArray,
        collection: ContractAddress,
        attributes: TokenAttributes
    ) {
        self.emit_event(@PVEBlobertInfo { id, name, collection, attributes });
    }

    fn set_pve_round(ref self: WorldStorage, id: felt252, round: u32) {
        self.write_member(Model::<PVEGame>::ptr_from_keys(id), selector!("round"), round);
    }

    fn set_pve_ended(ref self: WorldStorage, id: felt252, win: bool) {
        self
            .write_member(
                Model::<PVEGame>::ptr_from_keys(id), selector!("phase"), PVEPhase::Ended(win)
            );
    }
    fn get_pve_opponent_attacks(self: @WorldStorage, opponent_token: felt252) -> Array<felt252> {
        self.read_member(Model::<PVEOpponent>::ptr_from_keys(opponent_token), selector!("attacks"))
    }
    fn get_pve_opponent_stats(self: @WorldStorage, opponent_token: felt252) -> UStats {
        self.read_member(Model::<PVEOpponent>::ptr_from_keys(opponent_token), selector!("stats"))
    }

    fn get_collection_allowed(
        self: @WorldStorage, token_id: felt252, collection: ContractAddress
    ) -> bool {
        let value: PVECollectionAllowedValue = self.read_value((token_id, collection));
        value.allowed
    }

    fn set_collection_allowed(
        ref self: WorldStorage, token_id: felt252, collection: ContractAddress, allowed: bool
    ) {
        self.write_model(@PVECollectionAllowed { token_id, collection, allowed });
    }
    fn set_collections_allowed(
        ref self: WorldStorage,
        token_id: felt252,
        collections: Array<ContractAddress>,
        allowed: bool
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
        allowed: bool
    ) {
        let mut models = ArrayTrait::<@PVECollectionAllowed>::new();
        for token_id in token_ids {
            models.append(@PVECollectionAllowed { token_id, collection, allowed });
        };
        self.write_models(models.span());
    }
}
