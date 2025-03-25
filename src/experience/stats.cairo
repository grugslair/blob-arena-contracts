use core::cmp::min;

use starknet::{ContractAddress, get_contract_address};

use dojo::model::{Model, ModelStorage};
use dojo::world::{WorldStorage, IWorldDispatcher};

use crate::world::WorldTrait;
use crate::collections::{collection_dispatcher, ICollectionDispatcherTrait};
use crate::stats::{UStats, StatsTrait, MAX_STAT};

use super::ExperienceTrait;


const STATS_PER_LEVEL: u16 = 3;


fn calculate_max_experience_stats(experience: u128) -> u16 {
    0
}

#[generate_trait]
impl ExperienceStatsImpl of ExperienceStatsTrait {
    fn increase_stats(
        ref self: IWorldDispatcher,
        collection: ContractAddress,
        token: u256,
        player: ContractAddress,
        stats_increase: UStats,
    ) {
        let max_stats = calculate_max_experience_stats(
            self.get_experience(get_contract_address(), token, player),
        );
        let mut storage = self.default_storage();

        let new_stats = storage.get_experience_stats(collection, token, player) + stats_increase;

        assert(new_stats.sum() <= max_stats, 'Not enough experience');
        (new_stats + collection_dispatcher(collection).get_stats(token)).assert_in_range();

        storage.set_experience_stats(collection, token, player, new_stats);
    }

    fn remove_overflowing_stats(
        ref self: IWorldDispatcher,
        collection: ContractAddress,
        token: u256,
        player: ContractAddress,
    ) {
        let mut storage = self.default_storage();

        let current_stats = storage.get_experience_stats(collection, token, player);
        let base_stats = collection_dispatcher(collection).get_stats(token);
        storage
            .set_experience_stats(
                collection,
                token,
                player,
                UStats {
                    strength: min(current_stats.strength, MAX_STAT - base_stats.strength),
                    vitality: min(current_stats.vitality, MAX_STAT - base_stats.vitality),
                    dexterity: min(current_stats.dexterity, MAX_STAT - base_stats.dexterity),
                    luck: min(current_stats.luck, MAX_STAT - base_stats.luck),
                },
            );
    }
}

