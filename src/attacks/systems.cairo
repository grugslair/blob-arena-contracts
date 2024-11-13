use dojo::{world::WorldStorage, model::{ModelStorage, ModelValueStorage, Model}};
use blob_arena::{
    attacks::{
        Attack,
        components::{
            AttackInputTrait, AttackModelTrait, AttackInput, AttackModel,
            models::{PlannedAttack, AvailableAttack}
        }
    },
    uuid
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

#[generate_trait]
impl PlannedAttackImpl of PlannedAttackTrait {
    fn get_planned_attack(self: @WorldStorage, id: felt252) -> PlannedAttack {
        self.read_model(id)
    }
    fn set_planned_attack(
        ref self: WorldStorage, combatant_id: felt252, attack: felt252, target: felt252
    ) {
        self.write_model(@PlannedAttack { id: combatant_id, attack, target });
    }
    fn get_planned_attacks(self: @WorldStorage, mut ids: Span<felt252>) -> Span<PlannedAttack> {
        let mut attacks = ArrayTrait::<PlannedAttack>::new();
        loop {
            match ids.pop_front() {
                Option::Some(id) => { attacks.append(self.get_planned_attack(*id)); },
                Option::None => { break attacks.span(); },
            }
        }
    }
    fn clear_planned_attack(ref self: WorldStorage, id: felt252) {
        self.erase_model_ptr(Model::<PlannedAttack>::ptr_from_keys(id));
    }
    fn clear_planned_attacks(ref self: WorldStorage, mut ids: Span<felt252>) {
        loop {
            match ids.pop_front() {
                Option::Some(id) => { self.clear_planned_attack(*id); },
                Option::None => { break; },
            }
        };
    }
}

#[generate_trait]
impl AvailableAttackImpl of AvailableAttackTrait {
    fn get_available_attack(
        self: @WorldStorage, combatant_id: felt252, attack_id: felt252
    ) -> AvailableAttack {
        self.read_model((combatant_id, attack_id))
    }
    fn set_attack_available(ref self: WorldStorage, combatant_id: felt252, attack_id: felt252) {
        self
            .write_model(
                @AvailableAttack { combatant_id, attack_id, available: true, last_used: 0 }
            );
    }
    fn set_attack_last_used(
        ref self: WorldStorage, combatant_id: felt252, attack_id: felt252, last_used: u32
    ) {
        self.write_model(@AvailableAttack { combatant_id, attack_id, available: true, last_used });
    }
}

