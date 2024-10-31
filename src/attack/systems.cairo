use dojo::{world::WorldStorage, model::{ModelStorage, ModelValueStorage}};
use super::components::{
    Attack, AttackInput, AttackInputTrait, AttackModelTrait,
    models::{Attack as AttackModel, AvailableAttackValue}
};
use blob_arena::utils::uuid;
#[generate_trait]
impl AttackSystemImpl of AttackSystemTrait {}

#[generate_trait]
impl AttackImpl of AttackTrait {
    fn get_attack(self: @WorldStorage, id: felt252) -> Attack {
        ModelStorage::<WorldStorage, AttackModel>::read_model(self, id).to_attack()
    }
    fn get_attack_last_use(ref self: WorldStorage,) -> u32 {
        ModelValueStorage::<WorldStorage, AvailableAttackLastUsed>::read_value(self).last_used
    }
    fn create_new_attack(ref self: WorldStorage, attack: AttackInput) -> felt252 {
        let id = uuid();
        self.write_model(@attack.to_model(id));
        id
    }
    fn get_attack_speed(self: @WorldStorage, id: felt252) -> u8 {
        self.get_attack(id).speed
    }
    fn run_cooldown(
        ref self: WorldStorage, combatant: @Combatant, attack: Attack, round: u32
    ) -> bool {
        if attack.cooldown == 0 {
            return true;
        }
        let last_use = self
            .get_attack_last_use(*combatant.combat_id, *combatant.warrior_id, attack.id);
        if last_use.is_non_zero() && (attack.cooldown.into() + last_use) > round {
            return false;
        };
        self.set_attack_last_used(*combatant.combat_id, *combatant.warrior_id, attack.id, round);
        true
    }
}
