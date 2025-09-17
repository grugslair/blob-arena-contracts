use core::num::traits::{One, Zero};
use core::poseidon::poseidon_hash_span;
use sai_core_utils::SerdeAll;
use sai_core_utils::poseidon_serde::PoseidonSerde;
use sai_packing::ShiftCast;
use sai_packing::byte::{SHIFT_4B, SHIFT_6B};
pub use starknet::storage::{
    Map, Mutable, MutableVecTrait, StorageBase, StorageMapReadAccess, StorageMapWriteAccess,
    StoragePath, StoragePathEntry, StoragePointerReadAccess, Vec, VecTrait,
};
use super::Effect;
use super::effect::pack_effect_array;
const ATTACK_TAG_GROUP: felt252 = 'attacks';


/// Setup models

/// A struct representing an attack in the game.
///
/// # Fields
/// * `id` - Unique identifier for the attack
/// * `speed` - The speed of the attack (0-100)
/// * `chance` - The chance of the attack (0-100)
/// * `cooldown` - The cooldown period of the attack in rounds
/// * `success` - Array of effects that occur when the attack succeeds
/// * `fail` - Array of effects that occur when the attack fails
#[derive(Drop, Serde, Default, Introspect)]
pub struct Attack {
    pub speed: u16,
    pub chance: u8,
    pub cooldown: u32,
    pub success: Array<Effect>,
    pub fail: Array<Effect>,
}
/// A component representing an attack or input of attack in the game.
///
/// # Attributes
///
/// * `id` - A unique identifier for the attack.
/// * `speed` - The speed of the attack, represented as a value between 0 and 255.
/// * `chance` - The likelihood of the attack successting its target, represented as a value
/// between 0 and 100.
/// * `cooldown` - The number of turns required before the attack can be used again.
/// * `success` - An array of effects that are applied when the attack successfully successs.
/// * `fail` - An array of effects that are applied when the attack failes.
/// * `name` - The name of the attack. (For off chain use)

#[derive(Drop, Serde, Clone, Introspect)]
pub struct AttackWithName {
    pub name: ByteArray,
    pub speed: u16,
    pub chance: u8,
    pub cooldown: u32,
    pub success: Array<Effect>,
    pub fail: Array<Effect>,
}

impl AttackWithNameIntoAttack of Into<AttackWithName, Attack> {
    fn into(self: AttackWithName) -> Attack {
        Attack {
            speed: self.speed,
            chance: self.chance,
            cooldown: self.cooldown,
            success: self.success,
            fail: self.fail,
        }
    }
}


#[derive(Drop, Serde, Clone)]
pub enum IdTagAttack {
    Id: felt252,
    Tag: ByteArray,
    Attack: AttackWithName,
}


#[generate_trait]
pub impl AttackWithNameImpl of AttackWithNameTrait {
    fn attack_id(self: @AttackWithName) -> felt252 {
        get_attack_id(self.name, *self.speed, *self.chance, *self.cooldown, self.success, self.fail)
    }
}


pub fn get_attack_id(
    name: @ByteArray,
    speed: u16,
    chance: u8,
    cooldown: u32,
    success: @Array<Effect>,
    fail: @Array<Effect>,
) -> felt252 {
    let mut serialized: Array<felt252> = Default::default();
    let value: u64 = cooldown.into()
        + ShiftCast::cast::<SHIFT_4B>(speed)
        + ShiftCast::cast::<SHIFT_6B>(chance);

    Serde::serialize(name, ref serialized);
    serialized.append(value.into());
    serialized.append(success.len().into());
    serialized.append_span(pack_effect_array(success));
    serialized.append(fail.len().into());
    serialized.append_span(pack_effect_array(fail));
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


#[cfg(test)]
mod tests {
    use beacon_entity::get_schema_size;
    use crate::attack::Affect;
    use super::*;

    #[derive(Drop, Serde, Introspect)]
    struct AnAffect {
        affect: Affect,
    }
    #[test]
    fn table_size_test() {
        println!("AttackWithName size: {}", get_schema_size::<AttackWithName>());
        println!("Affect size: {}", get_schema_size::<AnAffect>());
    }
}
