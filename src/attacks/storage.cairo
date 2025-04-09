use starknet::ContractAddress;
use dojo::{
    world::{WorldStorage, WorldStorageTrait}, event::EventStorage,
    model::{ModelStorage, ModelValueStorage, Model},
};
use blob_arena::{
    attacks::{
        Attack, Effect,
        components::{
            AttackInputTrait, AttackInput, PlannedAttack, AttackAvailable, AttackLastUsed,
            AttackName, AttackExists, AttackUses,
        },
    },
    uuid, world::ModelsTrait, tags::Tag,
};


#[generate_trait]
impl AttackStorageImpl of AttackStorage {
    fn set_attack_model(ref self: WorldStorage, attack: Attack) {
        self.write_model(@attack);
    }
    fn set_attack_models(ref self: WorldStorage, attacks: Array<@Attack>) {
        self.write_models_check(attacks.span());
    }
    fn get_attack(self: @WorldStorage, id: felt252) -> Attack {
        self.read_model(id)
    }
    fn get_attacks(self: @WorldStorage, ids: Span<felt252>) -> Array<Attack> {
        self.read_models(ids)
    }
    fn emit_attack_name(ref self: WorldStorage, id: felt252, name: ByteArray) {
        self.emit_event(@AttackName { id, name });
    }

    fn get_planned_attack(self: @WorldStorage, id: felt252) -> PlannedAttack {
        self.read_model(id)
    }
    fn get_planned_attacks(self: @WorldStorage, ids: Span<felt252>) -> Span<PlannedAttack> {
        self.read_models(ids).span()
    }
    fn set_planned_attack(
        ref self: WorldStorage,
        combatant_id: felt252,
        attack_id: felt252,
        target: felt252,
        salt: felt252,
    ) {
        self.write_model(@PlannedAttack { combatant_id, attack_id, target, salt });
    }

    fn get_attack_ids_from_combatant_ids(
        self: @WorldStorage, combatant_ids: Span<felt252>,
    ) -> (Array<felt252>, Array<felt252>) {
        let mut attack_ids = ArrayTrait::<felt252>::new();
        let mut salts = ArrayTrait::<felt252>::new();
        for planned_attack in self.get_planned_attacks(combatant_ids) {
            attack_ids.append(*planned_attack.attack_id);
            salts.append(*planned_attack.salt);
        };
        (attack_ids, salts)
    }


    fn check_attack_available(
        self: @WorldStorage, combatant_id: felt252, attack_id: felt252,
    ) -> bool {
        self
            .read_member(
                Model::<AttackAvailable>::ptr_from_keys((combatant_id, attack_id)),
                selector!("available"),
            )
    }

    fn get_attack_last_used(self: @WorldStorage, combatant_id: felt252, attack_id: felt252) -> u32 {
        self
            .read_member(
                Model::<AttackLastUsed>::ptr_from_keys((combatant_id, attack_id)),
                selector!("last_used"),
            )
    }
    fn set_attack_available(ref self: WorldStorage, combatant_id: felt252, attack_id: felt252) {
        self.write_model(@AttackAvailable { combatant_id, attack_id, available: true });
    }
    fn set_combatant_attacks_available(
        ref self: WorldStorage, combatant_id: felt252, attack_ids: Span<felt252>,
    ) {
        let mut models = ArrayTrait::<@AttackAvailable>::new();

        for attack_id in attack_ids {
            models
                .append(@AttackAvailable { combatant_id, attack_id: *attack_id, available: true });
        };
        self.write_models(models.span());
    }
    fn set_attack_last_used(
        ref self: WorldStorage, combatant_id: felt252, attack_id: felt252, last_used: u32,
    ) {
        self.write_model(@AttackLastUsed { combatant_id, attack_id, last_used });
    }

    fn reset_attacks_last_used(
        ref self: WorldStorage, combatant_id: felt252, attack_ids: Array<felt252>,
    ) {
        let mut models = ArrayTrait::<@AttackLastUsed>::new();
        for attack_id in attack_ids {
            models.append(@AttackLastUsed { combatant_id, attack_id, last_used: 0 });
        };
        self.write_models(models.span());
    }
    fn clear_planned_attack(ref self: WorldStorage, id: felt252) {
        self.erase_model_ptr(Model::<PlannedAttack>::ptr_from_keys(id));
    }

    fn get_attack_cooldown(self: @WorldStorage, attack_id: felt252) -> u8 {
        self.read_member(Model::<Attack>::ptr_from_keys(attack_id), selector!("cooldown"))
    }


    fn get_attack_speeds(self: @WorldStorage, attack_ids: Span<felt252>) -> Array<u8> {
        let mut speeds = ArrayTrait::<u8>::new();
        for attack_id in attack_ids {
            speeds
                .append(
                    self
                        .read_member(
                            Model::<Attack>::ptr_from_keys(*attack_id), selector!("speed"),
                        ),
                );
        };
        speeds
    }

    fn get_attack_accuracy(self: @WorldStorage, attack_id: felt252) -> u8 {
        self.read_member(Model::<Attack>::ptr_from_keys(attack_id), selector!("accuracy"))
    }

    fn get_attack_hit_effects(self: @WorldStorage, attack_id: felt252) -> Array<Effect> {
        self.read_member(Model::<Attack>::ptr_from_keys(attack_id), selector!("hit"))
    }

    fn get_attack_miss_effects(self: @WorldStorage, attack_id: felt252) -> Array<Effect> {
        self.read_member(Model::<Attack>::ptr_from_keys(attack_id), selector!("miss"))
    }

    fn check_attack_exists(self: @WorldStorage, attack_id: felt252) -> bool {
        let schema: AttackExists = self.read_schema(Model::<Attack>::ptr_from_keys(attack_id));
        schema.hit.is_non_zero() || schema.miss.is_non_zero()
    }


    fn get_attack_uses(self: @WorldStorage, player: ContractAddress, attack_id: felt252) -> u32 {
        self.read_member(Model::<AttackUses>::ptr_from_keys((player, attack_id)), selector!("uses"))
    }

    fn set_attack_uses(
        ref self: WorldStorage, player: ContractAddress, attack_id: felt252, uses: u32,
    ) {
        self.write_model(@AttackUses { player, attack_id, uses });
    }
}

