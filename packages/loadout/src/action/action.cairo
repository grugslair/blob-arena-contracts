use ba_utils::storage::read_at_base_offset;
use core::num::traits::{DivRem, One, Zero};
use core::poseidon::poseidon_hash_span;
use sai_core_utils::poseidon_serde::PoseidonSerde;
use sai_core_utils::{SerdeAll, poseidon_hash_two};
use sai_packing::ShiftCast;
use sai_packing::byte::{SHIFT_4B, SHIFT_6B};
pub use starknet::storage::{
    Map, Mutable, MutableVecTrait, StorageBase, StorageMapReadAccess, StorageMapWriteAccess,
    StoragePath, StoragePathEntry, StoragePointerReadAccess, Vec, VecTrait,
};
use starknet::storage_access::StorageBaseAddress;
use crate::action::effect::EffectArrayReadWrite;
use super::effect::pack_effect_array;
use super::{Effect, effect};
const ATTACK_TAG_GROUP: felt252 = 'actions';
const NZ_MILLION: NonZero<u256> = 1_000_000;
const NZ_12: NonZero<u16> = 12;

pub struct Effects {
    pub chance: Array<(u32, Array<Effect>)>,
    pub base: Array<Effect>,
}


/// Setup models

/// A struct representing an action in the game.
///
/// # Fields
/// * `name` - The name of the action. (For off chain use)
/// * `speed` - The speed of the action (0 to 10000)
/// * `chance` - The chance of the action (0-100)
/// * `cooldown` - The cooldown period of the action in rounds
/// * `success` - Array of effects that occur when the action succeeds
/// * `fail` - Array of effects that occur when the action fails
#[derive(Drop, Serde, Default, Introspect)]
pub struct Action {
    pub speed: u16,
    pub cooldown: u32,
    pub base_effects: Array<Effect>,
    pub chance_effects: Array<(u32, Array<Effect>)>,
}

#[derive(Drop, Serde, Clone, Introspect)]
pub struct ActionWithName {
    pub name: ByteArray,
    pub speed: u16,
    pub cooldown: u32,
    pub base_effects: Array<Effect>,
    pub chance_effects: Array<(u32, Array<Effect>)>,
}

#[derive(Drop)]
struct EffectReader {
    action_id: felt252,
    storage_base: StorageBaseAddress,
    n: u16,
    current_chances: u256,
}

#[generate_trait]
impl EffectReaderImpl of EffectReaderTrait {
    fn next_chance(ref self: EffectReader) -> u32 {
        let (felt, n) = self.n.div_rem(NZ_12);
        if n.is_zero() {
            self
                .current_chances = read_at_base_offset(self.storage_base, felt.try_into().unwrap())
                .into();
        }
        let (quotient, remainder) = self.current_chances.div_rem(NZ_MILLION);
        self.current_chances = quotient;

        self.n += 1;
        remainder.try_into().unwrap()
    }

    fn get_effects(ref self: EffectReader, chance_value: u32) -> (u16, Array<Effect>) {
        let mut next_chance = self.next_chance();
        let mut current_chance = next_chance;
        while current_chance < chance_value && next_chance.is_non_zero() {
            next_chance = self.next_chance();
            current_chance += next_chance;
        }
        let mut n = if next_chance.is_zero() {
            *(@self).n
        } else {
            0
        };
        let effects = self.get_effects_at(n);
        (n, effects)
    }
    fn get_effects_at(self: @EffectReader, n: u16) -> Array<Effect> {
        EffectArrayReadWrite::read_short_array(
            poseidon_hash_two(*self.action_id, n).try_into().unwrap(),
        )
            .unwrap()
    }
}


fn write_effect_chances() {}


impl ActionWithNameIntoAction of Into<ActionWithName, Action> {
    fn into(self: ActionWithName) -> Action {
        Action {
            speed: self.speed,
            chance: self.chance,
            cooldown: self.cooldown,
            success: self.success,
            fail: self.fail,
        }
    }
}


/// A struct that combines an ID, a tag, or an action.
#[derive(Drop, Serde, Clone)]
pub enum IdTagAction {
    Id: felt252,
    Tag: ByteArray,
    Action: ActionWithName,
}


#[generate_trait]
pub impl ActionWithNameImpl of ActionWithNameTrait {
    fn action_id(self: ActionWithName) -> felt252 {
        let mut chance_effects: Array<(u32, Span<felt252>)> = Default::default();
        for (chance, effects) in self.chance_effects {
            chance_effects.append((chance, pack_effect_array(effects).span()));
        }
        get_action_id(
            @self.name,
            self.speed,
            self.cooldown,
            pack_effect_array(self.base_effects).span(),
            chance_effects.span(),
        )
    }
}


pub fn get_action_id(
    name: @ByteArray,
    speed: u16,
    cooldown: u32,
    base_effects: Span<felt252>,
    chance_effects: Span<(u32, Span<felt252>)>,
) -> felt252 {
    let mut serialized: Array<felt252> = Default::default();
    let value: u64 = cooldown.into() + ShiftCast::const_cast::<SHIFT_4B>(speed);
    let mut serialized = array![value.into()];

    Serde::serialize(name, ref serialized);
    serialized.append(value.into());
    serialized.append(success.len().into());
    serialized.append_span(success);
    serialized.append(fail.len().into());
    serialized.append_span(fail);
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

#[starknet::contract]
pub mod action_model {
    use super::ActionWithName;

    #[storage]
    struct Storage {}

    #[derive(Drop, starknet::Event)]
    struct Model {}

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Model: Model,
    }

    #[abi(embed_v0)]
    impl ActionWithNameModelImpl =
        beacon_entity::interface::ISaiModelImpl<ContractState, ActionWithName>;
}

#[cfg(test)]
mod tests {
    use beacon_entity::get_schema_size;
    use crate::action::Affect;
    use super::*;

    #[derive(Drop, Serde, Introspect)]
    struct AnAffect {
        affect: Affect,
    }
    #[test]
    fn table_size_test() {
        println!("ActionWithName size: {}", get_schema_size::<ActionWithName>());
        println!("Affect size: {}", get_schema_size::<AnAffect>());
    }
}
