use dojo::{
    world::{WorldStorage, WorldStorageTrait}, event::EventStorage,
    model::{ModelStorage, ModelValueStorage, Model}
};
use blob_arena::{
    attacks::{
        Attack,
        components::{AttackInputTrait, AttackInput, PlannedAttack, AvailableAttack, AttackName}
    },
    uuid, world::default_namespace
};

#[generate_trait]
impl AttackStorageImpl of AttackStorage {
    fn get_attack(self: @WorldStorage, id: felt252) -> Attack {
        self.read_model(id)
    }
    fn get_attacks(self: @WorldStorage, ids: Span<felt252>) -> Array<Attack> {
        self.read_models(ids)
    }
    fn create_attack(ref self: WorldStorage, attack_input: AttackInput) -> felt252 {
        let id = uuid();
        let (attack, name) = attack_input.to_attack_and_name(id);
        self.write_model(@attack);
        self.emit_event(@name);
        id
    }
    fn create_attacks(ref self: WorldStorage, attack_inputs: Array<AttackInput>) -> Array<felt252> {
        let mut attack_ids = ArrayTrait::<felt252>::new();
        let mut attacks = ArrayTrait::<@Attack>::new();
        for attack in attack_inputs {
            let id = uuid();
            let (attack, name) = attack.to_attack_and_name(id);
            attacks.append(@attack);
            self.emit_event(@name);
            attack_ids.append(id);
        };
        self.write_models(attacks.span());
        attack_ids
    }
    fn create_attacks_external(
        ref self: WorldStorage, attack_inputs: Array<AttackInput>
    ) -> Array<felt252> {
        let mut attack_world = WorldStorageTrait::new(self.dispatcher, default_namespace());
        attack_world.create_attacks(attack_inputs)
    }
    fn get_planned_attack(self: @WorldStorage, id: felt252) -> PlannedAttack {
        self.read_model(id)
    }
    fn get_planned_attacks(self: @WorldStorage, ids: Span<felt252>) -> Span<PlannedAttack> {
        self.read_models(ids).span()
    }
    fn set_planned_attack(
        ref self: WorldStorage, combatant_id: felt252, attack_id: felt252, target: felt252
    ) {
        self.write_model(@PlannedAttack { combatant_id, attack_id, target });
    }
    fn get_attacks_from_planned_attack_ids(
        self: @WorldStorage, ids: Span<felt252>
    ) -> Array<Attack> {
        let mut attack_ids = ArrayTrait::<felt252>::new();
        for planned_attack in self
            .get_planned_attacks(ids) {
                attack_ids.append(*planned_attack.attack_id);
            };
        self.get_attacks(attack_ids.span())
    }
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
    fn set_combatant_attacks_available(
        ref self: WorldStorage, combatant_id: felt252, attack_ids: Array<felt252>
    ) {
        let mut models = ArrayTrait::<@AvailableAttack>::new();
        for attack_id in attack_ids {
            models
                .append(
                    @AvailableAttack { combatant_id, attack_id, available: true, last_used: 0 }
                );
        };
        self.write_models(models.span());
    }
    fn set_attack_last_used(
        ref self: WorldStorage, combatant_id: felt252, attack_id: felt252, last_used: u32
    ) {
        self
            .write_member(
                Model::<AvailableAttack>::ptr_from_keys((combatant_id, attack_id)),
                selector!("last_used"),
                last_used
            );
    }
    fn clear_planned_attack(ref self: WorldStorage, id: felt252) {
        self.erase_model_ptr(Model::<PlannedAttack>::ptr_from_keys(id));
    }
}
