use core::poseidon::poseidon_hash_span;
use core::cmp::min;
use starknet::ContractAddress;
use starknet::storage::{StorageMapReadAccess, StorageMapWriteAccess};
use dojo::world::{WorldStorage, IWorldDispatcher};
use super::contract::experience::ContractState;
use super::events::ExperienceEvents;


fn experience_key(collection: ContractAddress, token: u256, player: ContractAddress) -> felt252 {
    poseidon_hash_span(
        [collection.into(), token.low.into(), token.high.into(), player.into()].span(),
    )
}

fn token_key(collection: ContractAddress, token: u256) -> felt252 {
    poseidon_hash_span([collection.into(), token.low.into(), token.high.into()].span())
}

fn collection_player_key(collection: ContractAddress, player: ContractAddress) -> felt252 {
    poseidon_hash_span([collection.into(), player.into()].span())
}

#[generate_trait]
impl ExperienceImpl of ExperienceTrait {
    fn increase_experience(
        ref self: ContractState,
        collection: ContractAddress,
        token: u256,
        player: ContractAddress,
        increase: u128,
    ) {
        let total_experience = self.increase_total_experience(increase);
        let collection_experience = self.increase_collection_experience(collection, increase);
        let player_experience = self.increase_player_experience(player, increase);
        let collection_player_experience = self
            .increase_collection_player_experience(collection, player, increase);
        let token_experience = self.increase_token_experience(collection, token, increase);
        let experience = self.increase_experience_value(collection, token, player, increase);
        self
            .emit_experiences(
                collection,
                token,
                player,
                total_experience,
                collection_experience,
                player_experience,
                collection_player_experience,
                token_experience,
                experience,
            );
    }

    fn increase_experience_value(
        ref self: ContractState,
        collection: ContractAddress,
        token: u256,
        player: ContractAddress,
        increase: u128,
    ) -> u128 {
        let key = experience_key(collection, token, player);
        let new_experience = self.experience.read(key) + increase;
        self.experience.write(key, new_experience);
        new_experience
    }

    fn increase_total_experience(ref self: ContractState, increase: u128) -> u128 {
        let new_experience = self.total_experience.read() + increase;
        self.total_experience.write(new_experience);
        new_experience
    }

    fn increase_player_experience(
        ref self: ContractState, player: ContractAddress, increase: u128,
    ) -> u128 {
        let new_experience = self.player_experience.read(player) + increase;
        self.player_experience.write(player, new_experience);
        new_experience
    }

    fn increase_collection_player_experience(
        ref self: ContractState,
        collection: ContractAddress,
        player: ContractAddress,
        increase: u128,
    ) -> u128 {
        let key = collection_player_key(collection, player);
        let new_experience = self.collection_player_experience.read(key) + increase;
        self.collection_player_experience.write(key, new_experience);
        new_experience
    }

    fn increase_token_experience(
        ref self: ContractState, collection: ContractAddress, token: u256, increase: u128,
    ) -> u128 {
        let key = token_key(collection, token);
        let new_experience = self.token_experience.read(key) + increase;
        self.token_experience.write(key, new_experience);
        new_experience
    }

    fn increase_collection_experience(
        ref self: ContractState, collection: ContractAddress, increase: u128,
    ) -> u128 {
        let new_experience = self.collection_experience.read(collection) + increase;
        self.collection_experience.write(collection, new_experience);
        new_experience
    }

    fn decrease_experience(
        ref self: ContractState,
        collection: ContractAddress,
        token: u256,
        player: ContractAddress,
        decrease: u128,
    ) {
        let (decrease, experience) = self
            .decrease_experience_value(collection, token, player, decrease);
        let total_experience = self.decrease_total_experience(decrease);
        let collection_experience = self.decrease_collection_experience(collection, decrease);
        let player_experience = self.decrease_player_experience(player, decrease);
        let collection_player_experience = self
            .decrease_collection_player_experience(collection, player, decrease);
        let token_experience = self.decrease_token_experience(collection, token, decrease);

        self
            .emit_experiences(
                collection,
                token,
                player,
                total_experience,
                collection_experience,
                player_experience,
                collection_player_experience,
                token_experience,
                experience,
            );
    }


    fn decrease_experience_value(
        ref self: ContractState,
        collection: ContractAddress,
        token: u256,
        player: ContractAddress,
        decrease: u128,
    ) -> (u128, u128) {
        let key = experience_key(collection, token, player);
        let decrease = min(decrease, self.experience.read(key));
        let new_experience = self.experience.read(key) - decrease;
        self.experience.write(key, new_experience);
        (decrease, new_experience)
    }

    fn decrease_total_experience(ref self: ContractState, decrease: u128) -> u128 {
        let new_experience = self.total_experience.read() - decrease;
        self.total_experience.write(new_experience);
        new_experience
    }

    fn decrease_player_experience(
        ref self: ContractState, player: ContractAddress, decrease: u128,
    ) -> u128 {
        let new_experience = self.player_experience.read(player) - decrease;
        self.player_experience.write(player, new_experience);
        new_experience
    }

    fn decrease_collection_player_experience(
        ref self: ContractState,
        collection: ContractAddress,
        player: ContractAddress,
        decrease: u128,
    ) -> u128 {
        let key = collection_player_key(collection, player);
        let new_experience = self.collection_player_experience.read(key) - decrease;
        self.collection_player_experience.write(key, new_experience);
        new_experience
    }

    fn decrease_token_experience(
        ref self: ContractState, collection: ContractAddress, token: u256, decrease: u128,
    ) -> u128 {
        let key = token_key(collection, token);
        let new_experience = self.token_experience.read(key) - decrease;
        self.token_experience.write(key, new_experience);
        new_experience
    }

    fn decrease_collection_experience(
        ref self: ContractState, collection: ContractAddress, decrease: u128,
    ) -> u128 {
        let new_experience = self.collection_experience.read(collection) - decrease;
        self.collection_experience.write(collection, new_experience);
        new_experience
    }
}
