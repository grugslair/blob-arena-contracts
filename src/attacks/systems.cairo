use core::num::traits::One;
use dojo::world::{WorldStorage, IWorldDispatcher, WorldStorageTrait};

use crate::attacks::{
    Attack, AttackStorage, AttackRequirement,
    components::{AttackInput, AttackInputTrait, ATTACK_TAG_GROUP},
};
use crate::tags::{Tag, IdTagNew};
use crate::world::{get_default_storage, WorldTrait};
use crate::hash::hash_value;
use crate::iter::Iteration;


#[generate_trait]
impl AttackImpl of AttackTrait {
    fn create_attack(ref self: WorldStorage, attack_input: AttackInput) -> felt252 {
        let id = hash_value(@attack_input);
        if !self.check_attack_exists(id) {
            let (attack, name) = attack_input.to_attack_and_name(id);
            self.set_attack_model(attack);
            self.set_tag(ATTACK_TAG_GROUP, @name, id);
            self.emit_attack_name(id, name);
        }
        id
    }
    fn create_attacks(
        ref self: WorldStorage, mut attack_inputs: Array<AttackInput>,
    ) -> Array<felt252> {
        let len = attack_inputs.len();
        if len.is_zero() {
            ArrayTrait::<felt252>::new()
        } else if len.is_one() {
            let id = self.create_attack(attack_inputs.pop_front().unwrap());
            array![id]
        } else {
            self._create_attacks(attack_inputs)
        }
    }
    fn _create_attacks(
        ref self: WorldStorage, attack_inputs: Array<AttackInput>,
    ) -> Array<felt252> {
        let mut attack_ids = ArrayTrait::<felt252>::new();
        let mut attacks = ArrayTrait::<@Attack>::new();
        let mut tags = ArrayTrait::<(@ByteArray, felt252)>::new();
        for attack in attack_inputs {
            let id = hash_value(@attack);
            if !self.check_attack_exists(id) {
                let (attack, name) = attack.to_attack_and_name(id);
                attacks.append(@attack);
                tags.append((@name, id));
                self.emit_attack_name(id, name);
            }
            attack_ids.append(id);
        };
        self.set_attack_models(attacks);
        self.set_tags(ATTACK_TAG_GROUP, tags);
        attack_ids
    }
    fn create_or_get_attack(ref self: WorldStorage, attack: IdTagNew<AttackInput>) -> felt252 {
        match attack {
            IdTagNew::Id(id) => id,
            IdTagNew::Tag(name) => self.get_tag(ATTACK_TAG_GROUP, @name),
            IdTagNew::New(attack) => self.create_attack(attack),
        }
    }

    fn create_or_get_attacks(
        ref self: WorldStorage, attacks: Array<IdTagNew<AttackInput>>,
    ) -> Array<felt252> {
        let mut models = ArrayTrait::<@Attack>::new();
        let mut tags = ArrayTrait::<(@ByteArray, felt252)>::new();
        let mut ids = ArrayTrait::<felt252>::new();
        for attack in attacks {
            ids
                .append(
                    match attack {
                        IdTagNew::Id(id) => id,
                        IdTagNew::Tag(name) => self.get_tag(ATTACK_TAG_GROUP, @name),
                        IdTagNew::New(attack) => {
                            let id = hash_value(@attack);
                            if !self.check_attack_exists(id) {
                                let (attack, name) = attack.to_attack_and_name(id);
                                models.append(@attack);
                                tags.append((@name, id));
                                self.emit_attack_name(id, name);
                            };
                            id
                        },
                    },
                );
        };
        self.set_attack_models(models);
        self.set_tags(ATTACK_TAG_GROUP, tags);
        ids
    }
    fn create_or_get_attack_external<T, +WorldTrait<T>, +Drop<T>>(
        ref self: T, attack: IdTagNew<AttackInput>,
    ) -> felt252 {
        let mut attack_world = self.default_storage();
        attack_world.create_or_get_attack(attack)
    }
    fn create_or_get_attacks_external<T, +WorldTrait<T>, +Drop<T>>(
        ref self: T, attacks: Array<IdTagNew<AttackInput>>,
    ) -> Array<felt252> {
        let mut attack_world = self.default_storage();
        attack_world.create_or_get_attacks(attacks)
    }
    fn check_attacks_requirements(
        self: @WorldStorage, experience: u128, attack_ids: Array<felt252>,
    ) -> Array<felt252> {
        let mut valid_attacks = ArrayTrait::<felt252>::new();
        for (n, requirements) in self.get_attacks_requirements(attack_ids.span()).enumerate() {
            if self.check_attack_requirements(experience, requirements) {
                valid_attacks.append(*attack_ids[n]);
            }
        };
        valid_attacks
    }

    fn check_attack_requirements(
        self: @WorldStorage, experience: u128, mut requirements: Array<AttackRequirement>,
    ) -> bool {
        loop {
            match requirements.pop_front() {
                Option::Some(requirements) => {
                    match requirements {
                        AttackRequirement::MinExperience(limit) => {
                            if limit > experience {
                                break false;
                            }
                        },
                        AttackRequirement::MaxExperience(limit) => {
                            if limit < experience {
                                break false;
                            }
                        },
                    }
                },
                Option::None => { break true; },
            }
        }
    }
}
