use dojo::{world::WorldStorage, model::{ModelStorage, ModelValueStorage}};
use blob_arena::{
    attacks::{Attack, components::{AttackInputTrait, AttackModelTrait, AttackInput, AttackModel}},
    utils::uuid
};

#[generate_trait]
impl AttackImpl of AttackTrait {
    fn get_attack(self: @WorldStorage, id: felt252) -> Attack {
        ModelStorage::<WorldStorage, AttackModel>::read_model(self, id).to_attack()
    }
    fn create_new_attack(ref self: WorldStorage, attack: @AttackInput) -> felt252 {
        let id = uuid();
        self.write_model(attack.to_model(id));
        id
    }
    fn get_attack_speed(self: @WorldStorage, id: felt252) -> u8 {
        self.get_attack(id).speed
    }
}
