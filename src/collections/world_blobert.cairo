use starknet::ContractAddress;

use dojo::world::{WorldStorage, IWorldDispatcher};
use dojo::model::{ModelStorage, Model};
use dojo::contract::components::world_provider::world_provider_cpt::{HasComponent, WorldProvider};

use crate::world::WorldTrait;

use super::{TokenAttributes, BlobertStore};
/// Game models

/// A struct representing a Blobert NFT token in the game.
///
/// # Fields
/// * `id` - Unique identifier for the Blobert token, used as a key
/// * `owner` - COntract address of the token owner
/// * `attributes` - Collection of token attributes
///
/// This model is used to store token ownership and attribute data for Bloberts in the game.
/// It is decorated with Dojo model and implements Drop and Serde traits.
#[dojo::model]
#[derive(Drop, Serde)]
struct BlobertToken {
    #[key]
    id: u256,
    owner: ContractAddress,
    attributes: TokenAttributes,
}

#[generate_trait]
impl WorldBlobertStorageImpl of WorldBlobertStorage {
    fn set_blobert_token(
        ref self: WorldStorage, id: u256, owner: ContractAddress, attributes: TokenAttributes,
    ) {
        self.write_model(@BlobertToken { id, owner, attributes });
    }

    fn get_blobert_token(self: @WorldStorage, token_id: u256) -> BlobertToken {
        let token_id: felt252 = token_id.try_into().unwrap();
        self.read_model(token_id)
    }
    fn get_blobert_token_owner(self: @WorldStorage, token_id: u256) -> ContractAddress {
        let token_id: felt252 = token_id.try_into().unwrap();
        self.read_member(Model::<BlobertToken>::ptr_from_keys(token_id), selector!("owner"))
    }

    fn get_blobert_token_attributes(self: @WorldStorage, token_id: u256) -> TokenAttributes {
        let token_id: felt252 = token_id.try_into().unwrap();
        self.read_member(Model::<BlobertToken>::ptr_from_keys(token_id), selector!("attributes"))
    }
}


impl WorldBlobertStore<
    const LOCAL_NAMESPACE_HASH: felt252, const ITEM_NAMESPACE_HASH: felt252,
> of BlobertStore {
    fn local_store(self: @IWorldDispatcher) -> WorldStorage {
        self.new_storage(LOCAL_NAMESPACE_HASH)
    }

    fn item_store(self: @IWorldDispatcher) -> WorldStorage {
        self.new_storage(ITEM_NAMESPACE_HASH)
    }

    fn attributes(self: @IWorldDispatcher, token_id: u256) -> TokenAttributes {
        Self::local_store(self).get_blobert_token_attributes(token_id)
    }

    fn owner(self: @IWorldDispatcher, token_id: u256) -> ContractAddress {
        Self::local_store(self).get_blobert_token_owner(token_id)
    }
}
