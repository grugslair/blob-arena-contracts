use core::num::traits::Zero;
use core::poseidon::poseidon_hash_span;
use core::cmp::min;
use starknet::{ContractAddress, get_contract_address};
use starknet::storage::{StorageMapReadAccess, StorageMapWriteAccess};
use dojo::world::{WorldStorage, IWorldDispatcher};

use crate::world::WorldTrait;
use crate::collections::{collection_dispatcher, ICollectionDispatcherTrait};
use crate::erc721::erc721_token_key;

use super::storage::{
    read_player_token_experience, write_player_token_experience, read_player_collection_experience,
    write_player_collection_experience, read_player_experience, write_player_experience,
    read_token_experience, write_token_experience, read_collection_experience,
    write_collection_experience, read_total_experience, write_total_experience,
};
use super::contract::experience_actions::ContractState;

fn increase_player_token(token_key: felt252, player: ContractAddress, increase: u128) -> u128 {
    let value = read_player_token_experience(player, token_key) + increase;
    write_player_token_experience(player, token_key, value);
    value
}
fn increase_player_collection(
    collection: ContractAddress, player: ContractAddress, increase: u128,
) -> u128 {
    let value = read_player_collection_experience(player, collection) + increase;
    write_player_collection_experience(player, collection, value);
    value
}
fn increase_player(player: ContractAddress, increase: u128) -> u128 {
    let value = read_player_experience(player) + increase;
    write_player_experience(player, value);
    value
}
fn increase_token_experience(token_key: felt252, increase: u128) -> u128 {
    let value = read_token_experience(token_key) + increase;
    write_token_experience(token_key, value);
    value
}
fn increase_collection_experience(collection: ContractAddress, increase: u128) -> u128 {
    let value = read_collection_experience(collection) + increase;
    write_collection_experience(collection, value);
    value
}
fn increase_total_experience(increase: u128) -> u128 {
    let value = read_total_experience() + increase;
    write_total_experience(value);
    value
}


#[generate_trait]
impl ExperienceImpl of ExperienceTrait {
    fn increase_experience<T, +WorldTrait<T>, +Drop<T>>(
        ref self: T,
        collection: ContractAddress,
        token: u256,
        player: ContractAddress,
        increase: u128,
    ) {
        let token_key = erc721_token_key(collection, token);

        if increase > 0 {
            let increase = storage.increase_experience_value(collection, token, player, increase);
            if increase > 0 {
                storage.increase_total_experiences(collection, token, player, increase);
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
}

