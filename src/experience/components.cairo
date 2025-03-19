use core::num::traits::Zero;
use starknet::ContractAddress;
use dojo::{world::{WorldStorage, IWorldDispatcher}, model::{Model, ModelStorage}};
use crate::world::WorldTrait;
use super::contract::experience::ContractState;

const NAMESPACE_HASH: felt252 = bytearray_hash!("experience");

#[dojo::model]
#[derive(Drop, Serde)]
struct Experience {
    #[key]
    player: ContractAddress,
    #[key]
    collection: ContractAddress,
    #[key]
    token: u256,
    experience: u128,
}

#[dojo::model]
#[derive(Drop, Serde)]
struct PlayerCollectionExperience {
    #[key]
    player: ContractAddress,
    #[key]
    collection: ContractAddress,
    experience: u128,
}

#[dojo::model]
#[derive(Drop, Serde)]
struct TokenExperience {
    #[key]
    collection: ContractAddress,
    #[key]
    token: u256,
    experience: u128,
}

#[dojo::model]
#[derive(Drop, Serde)]
struct PlayerExperience {
    #[key]
    player: ContractAddress,
    experience: u128,
}

#[dojo::model]
#[derive(Drop, Serde)]
struct CollectionExperience {
    #[key]
    collection: ContractAddress,
    experience: u128,
}

#[dojo::model]
#[derive(Drop, Serde)]
struct ExperienceCap {
    #[key]
    collection: ContractAddress,
    cap: u128,
}


#[generate_trait]
impl ExperienceStorageImpl of ExperienceStorage {
    fn get_experience_member<M, K, T, +Model<M>, +Drop<M>, +Serde<K>, +Drop<K>, +Serde<T>>(
        self: WorldStorage, keys: K,
    ) -> u128 {
        self.read_member(Model::<M>::ptr_from_keys(keys), selector!("experience"))
    }

    fn get_experience(
        self: WorldStorage, collection: ContractAddress, token: u256, player: ContractAddress,
    ) -> u128 {
        self.read_experience_member::<Experience>((collection, token, player))
    }

    fn get_token_experience(self: WorldStorage, collection: ContractAddress, token: u256) -> u128 {
        self.read_experience_member::<TokenExperience>((collection, token))
    }

    fn get_collection_player_experience(
        self: WorldStorage, collection: ContractAddress, player: ContractAddress,
    ) -> u128 {
        self.read_experience_member::<PlayerCollectionExperience>((player, collection))
    }

    fn get_player_experience(self: WorldStorage, player: ContractAddress) -> u128 {
        self.read_experience_member::<PlayerExperience>(player)
    }

    fn get_collection_experience(self: WorldStorage, collection: ContractAddress) -> u128 {
        self.read_experience_member::<CollectionExperience>(collection)
    }

    fn get_total_experience(self: WorldStorage) -> u128 {
        self.read_collection_experience(Zero::zero())
    }

    fn set_experience(
        ref self: WorldStorage,
        collection: ContractAddress,
        token: u256,
        player: ContractAddress,
        experience: u128,
    ) {
        self.write_model(@Experience { collection, token, player, experience });
    }

    fn set_token_experience(
        ref self: WorldStorage, collection: ContractAddress, token: u256, experience: u128,
    ) {
        self.write_model(@TokenExperience { collection, token, experience });
    }

    fn set_collection_player_experience(
        ref self: WorldStorage,
        collection: ContractAddress,
        player: ContractAddress,
        experience: u128,
    ) {
        self.write_model(@PlayerCollectionExperience { collection, player, experience });
    }

    fn set_player_experience(ref self: WorldStorage, player: ContractAddress, experience: u128) {
        self.write_model(@PlayerExperience { player, experience });
    }

    fn set_collection_experience(
        ref self: WorldStorage, collection: ContractAddress, experience: u128,
    ) {
        self.write_model(@CollectionExperience { collection, experience });
    }

    fn set_total_experience(ref self: WorldStorage, experience: u128) {
        self.set_collection_experience(Zero::zero(), experience);
    }

    fn get_experience_cap(self: WorldStorage, collection: ContractAddress) -> u128 {
        self.read_member(Model::<ExperienceCap>::ptr_from_keys(collection), selector!("cap"))
    }

    fn experience_storage(self: WorldStorage) -> WorldStorage {
        self.new_storage(NAMESPACE_HASH)
    }
}
