use core::num::traits::{One, Zero};
use core::poseidon::poseidon_hash_span;
use sai_core_utils::SerdeAll;
use sai_core_utils::poseidon_serde::PoseidonSerde;
pub use starknet::storage::{
    Map, Mutable, MutableVecTrait, StorageBase, StorageMapReadAccess, StorageMapWriteAccess,
    StoragePath, StoragePathEntry, StoragePointerReadAccess, Vec, VecTrait,
};
use crate::ability::{AbilityTypes, DAbilities};
const ATTACK_TAG_GROUP: felt252 = 'attacks';


/// Setup models

/// A struct representing an attack in the game.
///
/// # Fields
/// * `id` - Unique identifier for the attack
/// * `speed` - The speed of the attack (0-100)
/// * `accuracy` - The accuracy of the attack (0-100)
/// * `cooldown` - The cooldown period of the attack in rounds
/// * `hit` - Array of effects that occur when the attack hits
/// * `miss` - Array of effects that occur when the attack misses
#[derive(Drop, Serde, Default, Introspect)]
pub struct Attack {
    pub speed: u32,
    pub accuracy: u8,
    pub cooldown: u8,
    pub hit: Array<Effect>,
    pub miss: Array<Effect>,
}
/// A component representing an attack or input of attack in the game.
///
/// # Attributes
///
/// * `id` - A unique identifier for the attack.
/// * `speed` - The speed of the attack, represented as a value between 0 and 255.
/// * `accuracy` - The likelihood of the attack hitting its target, represented as a value between 0
/// and 100.
/// * `cooldown` - The number of turns required before the attack can be used again.
/// * `hit` - An array of effects that are applied when the attack successfully hits.
/// * `miss` - An array of effects that are applied when the attack misses.
/// * `name` - The name of the attack. (For off chain use)

#[derive(Drop, Serde, Clone, Introspect)]
pub struct AttackWithName {
    pub name: ByteArray,
    pub speed: u32,
    pub accuracy: u8,
    pub cooldown: u8,
    pub hit: Array<Effect>,
    pub miss: Array<Effect>,
}

impl AttackWithNameIntoAttack of Into<AttackWithName, Attack> {
    fn into(self: AttackWithName) -> Attack {
        Attack {
            speed: self.speed,
            accuracy: self.accuracy,
            cooldown: self.cooldown,
            hit: self.hit,
            miss: self.miss,
        }
    }
}

/// Represents an effect that can be applied during the game.
///
/// # Arguments
/// * `target` - Specifies who receives the effect (Player or Opponent)
/// * `affect` - The type of effect to be applied

#[derive(Drop, Serde, Copy, PartialEq, Introspect, starknet::Store)]
pub struct Effect {
    pub target: Target,
    pub affect: Affect,
}


#[derive(Drop, Serde, Copy, PartialEq, Introspect, Default, starknet::Store)]
pub enum Target {
    #[default]
    Player,
    Opponent,
}

/// Represents different types of effects that can be applied in the game
/// * `Abilities` - Multiple ability modifications applied at once using SignedAbilities
/// * `Ability` - A single ability modification using Ability
/// * `Damage` - Direct damage effect
/// * `Stun` - Stun chance increase of target on next attack in percentage
/// * `Health` - Health modification (can be positive for healing or negative for damage)

#[derive(Drop, Serde, Copy, PartialEq, Introspect, Default, starknet::Store)]
pub enum Affect {
    #[default]
    Health: i32,
    Abilities: DAbilities,
    Ability: AbilityAffect,
    Damage: Damage,
    Stun: u8,
}


#[derive(Drop, Serde, Clone)]
pub enum IdTagAttack {
    Id: felt252,
    Tag: ByteArray,
    Attack: AttackWithName,
}

/// Represents a modifier to a ability in the game.
/// * `ability` - The type of abilityistic (Strength, Vitality, Dexterity, Luck)
/// * `amount` - The numerical value of the ability, ranging from -100 to +100

#[derive(Drop, Serde, Copy, PartialEq, Introspect, starknet::Store)]
pub struct AbilityAffect {
    pub ability: AbilityTypes,
    pub amount: i32,
}

/// Represents damage attributes of an attack.
/// * `critical` - Critical hit chance value between 0-100
/// * `power` - Attack power value between 0-100

#[derive(Drop, Serde, Copy, PartialEq, Introspect, starknet::Store)]
pub struct Damage {
    pub critical: u8,
    pub power: u32,
}

#[generate_trait]
pub impl AttackWithNameImpl of AttackWithNameTrait {
    fn attack_id(self: @AttackWithName) -> felt252 {
        get_attack_id(self.name, *self.speed, *self.accuracy, *self.cooldown, self.hit, self.miss)
    }
}

pub fn get_attack_id(
    name: @ByteArray,
    speed: u32,
    accuracy: u8,
    cooldown: u8,
    hit: @Array<Effect>,
    miss: @Array<Effect>,
) -> felt252 {
    let mut serialized: Array<felt252> = Default::default();
    Serde::serialize(name, ref serialized);
    serialized.append_span([speed.into(), accuracy.into(), cooldown.into()].span());
    Serde::serialize(hit, ref serialized);
    Serde::serialize(miss, ref serialized);

    poseidon_hash_span(serialized.span())
}


pub impl EffectArrayStorageMapWriteAccess of StorageMapWriteAccess<
    StorageBase<Mutable<Map<felt252, Vec<Effect>>>>,
> {
    type Key = felt252;
    type Value = Array<Effect>;
    fn write(
        self: StorageBase<Mutable<Map<felt252, Vec<Effect>>>>, key: felt252, value: Array<Effect>,
    ) {
        let mut vec = self.entry(key);
        for effect in value {
            vec.push(effect);
        }
    }
}

pub impl EffectArrayStorageMapReadAccess of StorageMapReadAccess<
    StorageBase<Map<felt252, Vec<Effect>>>,
> {
    type Key = felt252;
    type Value = Array<Effect>;
    fn read(self: StorageBase<Map<felt252, Vec<Effect>>>, key: felt252) -> Array<Effect> {
        let ptr = self.entry(key);
        let mut effects: Array<Effect> = Default::default();
        for i in 0..ptr.len() {
            effects.append(ptr.at(i).read());
        }
        effects
    }
}


pub fn byte_array_to_tag(array: @ByteArray) -> felt252 {
    let serialized = array.serialize_all();
    let data_len = serialized.len() - 3;
    let pending_word = *serialized.at(data_len + 1);
    let pending_word_len = *serialized.at(data_len + 2);
    if data_len.is_zero() {
        return pending_word;
    } else if data_len.is_one() && pending_word_len.is_zero() {
        return *serialized.at(0);
    }
    let mut data = serialized.slice(1, data_len);
    if pending_word.is_zero() {
        poseidon_hash_span(data)
    } else {
        let mut data: Array<felt252> = data.into();
        data.append(pending_word);
        poseidon_hash_span(data.span())
    }
}
