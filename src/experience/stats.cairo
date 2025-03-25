use core::cmp::min;

use starknet::{ContractAddress, get_contract_address};

use dojo::model::{Model, ModelStorage};
use dojo::world::{WorldStorage, IWorldDispatcher};
use crate::collections::{ICollectionDispatcher, ICollectionDispatcherTrait}
use crate::stats::{UStats, StatsTrait, MAX_STAT};
use super::ExperienceTrait;


const STATS_PER_LEVEL: u16 = 3;

#[dojo::model]
#[derive(Drop, Serde)]
struct ExperienceStats {
    #[key]
    collection: ContractAddress, 
    #[key]
    token: u256,
    #[key]
    player: ContractAddress,
    strength: u8,
    vitality: u8,
    dexterity: u8,
    luck: u8,
}

fn calculate_max_experience_stats(experience: u128) -> u16 {
    0
}

#[generate_trait]
impl ExperienceStatsStorageImpl of ExperienceStatsStorage {
    fn get_blobert_experience_stats(
        self: @WorldStorage, collection: ContractAddress, token: u256, player: ContractAddress,
    ) -> UStats {
        self.read_schema(Model::<ExperienceStats>::ptr_from_keys((token, player)))
    }

    fn set_blobert_experience_stats(
        ref self: WorldStorage,collection: ContractAddress,  token: u256, player: ContractAddress, stats: UStats,
    ) {
        let UStats { strength, vitality, dexterity, luck } = stats;
        self.write_model(@ExperienceStats { token, player, strength, vitality, dexterity, luck });
    }
}

#[generate_trait]
impl ExperienceStatsImpl of ExperienceStatsTrait {
    fn increase_stats(
        ref self: IWorldDispatcher, collection: ContractAddress, token: u256, player: ContractAddress, stats_increase: UStats,
    ) {
        let max_stats = calculate_max_experience_stats(
            self.get_experience(get_contract_address(), token, player),
        );
        let mut storage = self.local_store();

        let new_stats = storage.get_blobert_experience_stats(token, player) + stats_increase;

        assert(new_stats.sum() <= max_stats, 'Not enough experience');
        (new_stats + self.get_base_stats(token)).assert_in_range();

        storage.set_blobert_experience_stats(token, player, new_stats);
    }

    fn remove_overflowing_stats(ref self: IWorldDispatcher,collection: ContractAddress,  token: u256, player: ContractAddress) {
        let mut storage = self.local_store();

        let current_stats = storage.get_blobert_experience_stats(token, player);
        let base_stats = self.get_base_stats(token);
        storage
            .set_blobert_experience_stats(
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

