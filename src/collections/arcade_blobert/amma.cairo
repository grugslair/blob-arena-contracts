use starknet::{ContractAddress, get_caller_address};
use dojo::{world::WorldStorage, model::{ModelStorage, ModelValueStorage}};
use blob_arena::{
    core::TTupleSize5, hash::{hash_value}, world::WorldTrait,
    collections::{blobert::{external::TokenTrait}, arcade_blobert::blobert::ArcadeBlobertTrait},
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
    fn get_custom_id(self: @WorldStorage, fighter_id: u8) -> u8 {
        ModelValueStorage::<WorldStorage, AMMABlobertValue>::read_value(self, fighter_id).custom_id
    }

    fn mint_amma_blobert(
        ref self: WorldStorage, owner: ContractAddress, fighter_id: u8
    ) -> felt252 {
        let custom_id = self.get_custom_id(fighter_id);
        let token_id = hash_value((owner, custom_id));
        self.set_arcade_blobert(token_id, owner, TokenTrait::Custom(custom_id));
        token_id
    }
    fn set_amma_blobert(ref self: WorldStorage, fighter_id: u8, name: ByteArray, custom_id: u8) {
        self.assert_caller_is_creator();
        self.write_model(@AMMABlobert { fighter_id, name, custom_id });
    }
}
