use core::{poseidon::{poseidon_hash_span, HashState, PoseidonTrait}, hash::HashStateExTrait};
use dojo::{world::WorldStorage, model::{Model, ModelStorage, ModelPtr}};
use blob_arena::hash::SpanHash;

mod models {
    #[dojo::model]
    #[derive(Drop, Serde)]
    struct Salts {
        #[key]
        id: felt252,
        salts: Span<felt252>
    }
}
use models::{Salts as SaltsModel};

#[generate_trait]
impl SaltsImpl of Salts {
    fn get_salts_model(ref self: WorldStorage, id: felt252) -> SaltsModel {
        self.read_model(id)
    }

    fn set_salts(ref self: WorldStorage, id: felt252, salts: Span<felt252>) {
        self.write_model(@SaltsModel { id, salts: salts });
    }

    fn append_salt(ref self: WorldStorage, id: felt252, salt: felt252) {
        let mut salts: Array<felt252> = self.get_salts(id).into();
        salts.append(salt);
        self.set_salts(id, salts.span());
    }

    fn reset_salts(ref self: WorldStorage, id: felt252) {
        self.erase_model_ptr(Model::<SaltsModel>::ptr_from_keys(id));
    }
    fn get_salts(ref self: WorldStorage, id: felt252) -> Span<felt252> {
        self.get_salts_model(id).salts
    }


    fn get_salts_hash(ref self: WorldStorage, id: felt252) -> felt252 {
        poseidon_hash_span(self.get_salts(id))
    }

    fn get_salts_hash_state(ref self: WorldStorage, id: felt252) -> HashState {
        PoseidonTrait::new().update_with(self.get_salts(id))
    }
}
