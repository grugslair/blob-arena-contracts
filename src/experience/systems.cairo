use core::num::traits::Zero;
use core::poseidon::poseidon_hash_span;
use core::cmp::min;
use starknet::{ContractAddress, get_contract_address};
use starknet::storage::{StorageMapReadAccess, StorageMapWriteAccess};
use dojo::world::{WorldStorage, IWorldDispatcher};

use crate::world::WorldTrait;
use crate::collections::{collection_dispatcher, ICollectionDispatcherTrait};
use crate::stats::{UStats, StatsTrait, MAX_STAT};

use super::ExperienceStorage;

const STATS_PER_LEVEL: u16 = 3;


fn calculate_max_experience_stats(experience: u128) -> u16 {
    0
}

#[generate_trait]
impl ExperienceImpl of ExperienceTrait {
    fn get_experience<T, +WorldTrait<T>, +Drop<T>>(
        self: @T, collection: ContractAddress, token: u256, player: ContractAddress,
    ) -> u128 {
        self.experience_storage().get_experience_value(collection, token, player)
    }
    fn get_experience_stats<T, +WorldTrait<T>, +Drop<T>>(
        self: @T, collection: ContractAddress, token: u256, player: ContractAddress,
    ) -> UStats {
        self.experience_storage().get_experience_stats_value(collection, token, player)
    }
    fn increase_experience<T, +WorldTrait<T>, +Drop<T>>(
        ref self: T,
        collection: ContractAddress,
        token: u256,
        player: ContractAddress,
        increase: u128,
    ) {
        let mut storage = self.experience_storage();
        if increase > 0 {
            let increase = storage.increase_experience_value(collection, token, player, increase);
            if increase > 0 {
                storage.increase_total_experiences(collection, token, player, increase);
            }
        }
    }

    fn decrease_experience(
        ref self: IWorldDispatcher,
        collection: ContractAddress,
        token: u256,
        player: ContractAddress,
        decrease: u128,
    ) {
        let mut storage = self.experience_storage();
        if decrease > 0 {
            let decrease = storage.decrease_experience_value(collection, token, player, decrease);
            if decrease > 0 {
                storage.decrease_total_experiences(collection, token, player, decrease);
            }
        }
    }

    fn increase_experience_value(
        ref self: WorldStorage,
        collection: ContractAddress,
        token: u256,
        player: ContractAddress,
        increase: u128,
    ) -> u128 {
        let cap = self.get_experience_cap(collection);
        let experience = self.get_experience_value(collection, token, player);
        if experience >= cap {
            0
        } else if experience + increase > cap {
            self.set_experience(collection, token, player, cap);
            cap - experience
        } else {
            self.set_experience(collection, token, player, experience + increase);
            increase
        }
    }

    fn decrease_experience_value(
        ref self: WorldStorage,
        collection: ContractAddress,
        token: u256,
        player: ContractAddress,
        decrease: u128,
    ) -> u128 {
        let experience = self.get_experience_value(collection, token, player);
        if experience < decrease {
            self.set_experience(collection, token, player, 0);
            experience
        } else {
            self.set_experience(collection, token, player, experience - decrease);
            decrease
        }
    }

    fn increase_total_experiences(
        ref self: WorldStorage,
        collection: ContractAddress,
        token: u256,
        player: ContractAddress,
        increase: u128,
    ) {
        self.set_player_experience(player, self.get_player_experience(player) + increase);
        self
            .set_collection_experience(
                collection, self.get_collection_experience(collection) + increase,
            );
        self
            .set_token_experience(
                collection, token, self.get_token_experience(collection, token) + increase,
            );
        self
            .set_collection_player_experience(
                collection,
                player,
                self.get_collection_player_experience(collection, player) + increase,
            );
        self.set_total_experience(self.get_total_experience() + increase);
    }

    fn decrease_total_experiences(
        ref self: WorldStorage,
        collection: ContractAddress,
        token: u256,
        player: ContractAddress,
        decrease: u128,
    ) {
        self.set_player_experience(player, self.get_player_experience(player) - decrease);
        self
            .set_collection_experience(
                collection, self.get_collection_experience(collection) - decrease,
            );
        self
            .set_token_experience(
                collection, token, self.get_token_experience(collection, token) - decrease,
            );
        self
            .set_collection_player_experience(
                collection,
                player,
                self.get_collection_player_experience(collection, player) - decrease,
            );
        self.set_total_experience(self.get_total_experience() - decrease);
    }

    fn allocate_experience_stats(
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

    fn remove_overflowing_experience_stats(
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

