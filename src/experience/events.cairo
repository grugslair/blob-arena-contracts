use core::num::traits::Zero;
use starknet::ContractAddress;
use dojo::{world::{WorldStorage, IWorldDispatcher}, model::{Model, ModelStorage}};
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

// #[generate_trait]
// impl ExperienceStorageImpl of ExperienceEvents {
//     fn emit_experiences(
//         ref self: ContractState,
//         collection: ContractAddress,
//         token: u256,
//         player: ContractAddress,
//         total_experience: u128,
//         collection_experience: u128,
//         player_experience: u128,
//         collection_player_experience: u128,
//         token_experience: u128,
//         experience: u128,
//     ) {
//         let mut world = WorldStorage {
//             dispatcher: IWorldDispatcher { contract_address: self.world_address.read() },
//             namespace_hash: NAMESPACE_HASH,
//         };
//         world.emit_event(@Experience { collection, token, player, experience });
//         world
//             .emit_event(
//                 @CollectionPlayerExperience {
//                     collection, player, experience: collection_player_experience,
//                 },
//             );
//         world.emit_event(@TokenExperience { collection, token, experience: token_experience });
//         world.emit_event(@PlayerExperience { player, experience: player_experience });
//         world.emit_event(@TotalExperience { collection, experience: collection_experience });
//         world
//             .emit_event(
//                 @TotalExperience { collection: Zero::zero(), experience: collection_experience },
//             );
//     }
// }

#[generate_trait]
impl ExperienceStorageImpl of ExperienceStorage {}
