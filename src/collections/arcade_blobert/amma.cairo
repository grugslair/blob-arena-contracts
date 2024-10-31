use starknet::{ContractAddress, get_caller_address};
use dojo::world::{WorldStorage, ModelStorage};
use blob_arena::{
    core::TTupleSize5, utils::{hash_value, HashStateTrait}, world::WorldTrait,
    collections::{
        blobert::{external::TokenTrait},
        arcade_blobert::blobert::{ArcadeBlobert, ArcadeBlobertStore}
    },
};

#[dojo::model]
#[derive(Drop, Serde)]
struct AMMABlobert {
    #[key]
    fighter_id: u8,
    name: ByteArray,
    custom_id: u8,
}

#[generate_trait]
impl AMMABlobertImpl of AMMABlobertTrait {
    fn mint_amma_blobert(
        ref self: WorldStorage, owner: ContractAddress, fighter_id: u8
    ) -> felt252 {
        let custom_id = AMMABlobertStore::get_custom_id(self, fighter_id);
        let token_id = hash_value((owner, custom_id));
        ArcadeBlobert { token_id, owner, traits: TokenTrait::Custom(custom_id) }.set(self);
        token_id
    }
    fn set_amma_blobert(ref self: WorldStorage, fighter_id: u8, name: ByteArray, custom_id: u8) {
        self.assert_caller_is_owner();
        AMMABlobert { fighter_id, name, custom_id }.set(self);
    }
}
