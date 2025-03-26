use core::num::traits::Zero;
use starknet::ContractAddress;
use dojo::{world::{WorldStorage, IWorldDispatcher}, model::{Model, ModelStorage}};
use crate::world::WorldTrait;
use crate::stats::UStats;
const STORAGE_NAMESPACE_HASH: felt252 = bytearray_hash!("experience");

/// Experience model tracks a player's experience points for a specific token in a collection
///
/// # Arguments
///
/// * `player` - The address of the player
/// * `collection` - The address of the NFT collection contract
/// * `token` - The token ID within the collection
/// * `experience` - The amount of experience points accumulated
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

/// Represents a player's experience for a specific NFT collection
///
/// # Arguments
///
/// * `player` - The address of the player
/// * `collection` - The address of the NFT collection
/// * `experience` - The amount of experience points earned for this collection
#[dojo::model]
#[derive(Drop, Serde)]
struct PlayerCollectionExperience {
    #[key]
    player: ContractAddress,
    #[key]
    collection: ContractAddress,
    experience: u128,
}

/// Records and tracks experience points (XP) for specific tokens within a collection
///
/// # Fields
/// * `collection` - The contract address of the NFT collection
/// * `token` - The unique identifier of the specific token within the collection
/// * `experience` - The amount of experience points accumulated by the token
#[dojo::model]
#[derive(Drop, Serde)]
struct TokenExperience {
    #[key]
    collection: ContractAddress,
    #[key]
    token: u256,
    experience: u128,
}

/// Represents a player's experience points in the game
///
/// # Fields
///
/// * `player` - The ContractAddress representing the player's unique identifier
/// * `experience` - The amount of experience points the player has accumulated
#[dojo::model]
#[derive(Drop, Serde)]
struct PlayerExperience {
    #[key]
    player: ContractAddress,
    experience: u128,
}

/// A model component representing the experience points accumulated by a collection
///
/// # Arguments
/// * `collection` - The contract address of the collection
/// * `experience` - The amount of experience points the collection has accumulated
#[dojo::model]
#[derive(Drop, Serde)]
struct CollectionExperience {
    #[key]
    collection: ContractAddress,
    experience: u128,
}

/// Represents the maximum experience points achievable for a specific collection
///
/// # Fields
///
/// * `collection` - The contract address of the collection this cap applies to
/// * `cap` - The maximum experience points that can be earned for a token in this collection
#[dojo::model]
#[derive(Drop, Serde)]
struct ExperienceCap {
    #[key]
    collection: ContractAddress,
    cap: u128,
}

/// Represents the bonus experience stats for a player's NFT.
///
/// # Fields
///
/// * `collection` - The NFT collection contract address
/// * `token` - The specific NFT token ID within the collection
/// * `player` - The wallet address of the player who owns the NFT
/// * `strength` - The strength stat of the NFT (0-100)
/// * `vitality` - The vitality stat of the NFT (0-100)
/// * `dexterity` - The dexterity stat of the NFT (0-100)
/// * `luck` - The luck stat of the NFT (0-100)
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


#[generate_trait]
impl ExperienceStorageImpl of ExperienceStorage {
    fn get_experience_member<M, K, +Model<M>, +Drop<M>, +Serde<K>, +Drop<K>>(
        self: @WorldStorage, keys: K,
    ) -> u128 {
        self.read_member(Model::<M>::ptr_from_keys(keys), selector!("experience"))
    }

    fn get_experience_value(
        self: @WorldStorage, collection: ContractAddress, token: u256, player: ContractAddress,
    ) -> u128 {
        self.get_experience_member::<Experience>((collection, token, player))
    }

    fn get_token_experience(self: @WorldStorage, collection: ContractAddress, token: u256) -> u128 {
        self.get_experience_member::<TokenExperience>((collection, token))
    }

    fn get_collection_player_experience(
        self: @WorldStorage, collection: ContractAddress, player: ContractAddress,
    ) -> u128 {
        self.get_experience_member::<PlayerCollectionExperience>((player, collection))
    }

    fn get_player_experience(self: @WorldStorage, player: ContractAddress) -> u128 {
        self.get_experience_member::<PlayerExperience>(player)
    }

    fn get_collection_experience(self: @WorldStorage, collection: ContractAddress) -> u128 {
        self.get_experience_member::<CollectionExperience>(collection)
    }

    fn get_total_experience(self: @WorldStorage) -> u128 {
        self.get_collection_experience(Zero::zero())
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

    fn get_experience_cap(self: @WorldStorage, collection: ContractAddress) -> u128 {
        self.read_member(Model::<ExperienceCap>::ptr_from_keys(collection), selector!("cap"))
    }

    fn set_experience_cap(ref self: WorldStorage, collection: ContractAddress, cap: u128) {
        self.write_model(@ExperienceCap { collection, cap });
    }

    fn experience_storage<T, +WorldTrait<T>, +Drop<T>>(self: @T) -> WorldStorage {
        self.storage(STORAGE_NAMESPACE_HASH)
    }

    fn get_experience_stats_value(
        self: @WorldStorage, collection: ContractAddress, token: u256, player: ContractAddress,
    ) -> UStats {
        self.read_schema(Model::<ExperienceStats>::ptr_from_keys((token, player)))
    }

    fn set_experience_stats(
        ref self: WorldStorage,
        collection: ContractAddress,
        token: u256,
        player: ContractAddress,
        stats: UStats,
    ) {
        let UStats { strength, vitality, dexterity, luck } = stats;
        self
            .write_model(
                @ExperienceStats { collection, token, player, strength, vitality, dexterity, luck },
            );
    }
}
