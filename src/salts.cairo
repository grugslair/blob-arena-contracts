use core::{poseidon::{poseidon_hash_span, HashState, PoseidonTrait}, hash::HashStateExTrait};
use dojo::{world::WorldStorage, model::{Model, ModelStorage, ModelPtr}};
use blob_arena::hash::ArrayHash;
type Salts = Array<felt252>;

mod models {
    #[dojo::model]
    #[derive(Drop, Serde)]
    struct Salts {
        #[key]
        id: felt252,
        salts: Array<felt252>
    }
}
use models::{Salts as SaltsModel};

#[generate_trait]
impl SaltsImpl of SaltsTrait {
    fn get_salts_model(ref self: WorldStorage, id: felt252) -> SaltsModel {
        self.read_model(id)
    }

    fn set_salts(ref self: WorldStorage, id: felt252, salts: Salts) {
        self.write_model(@SaltsModel { id, salts: salts });
    }

    fn append_salt(ref self: WorldStorage, id: felt252, salt: felt252) {
        let mut salts = self.get_salts(id);
        salts.append(salt);
        self.set_salts(id, salts);
    }

    fn reset_salts(ref self: WorldStorage, id: felt252) {
        self.erase_model_ptr(ModelPtr::<SaltsModel>::Keys([id].span()));
    }
    fn get_salts(ref self: WorldStorage, id: felt252) -> Salts {
        self.get_salts_model(id).salts
    }


    fn get_salts_hash(ref self: WorldStorage, id: felt252) -> felt252 {
        poseidon_hash_span(self.get_salts(id).span())
    }

    fn get_salts_hash_state(ref self: WorldStorage, id: felt252) -> HashState {
        PoseidonTrait::new().update_with(self.get_salts(id))
    }
}
