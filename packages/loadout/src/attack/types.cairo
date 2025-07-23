use core::poseidon::poseidon_hash_span;
use sai_core_utils::poseidon_serde::PoseidonSerde;
pub use starknet::storage::{
    Map, Mutable, MutableVecTrait, StorageBase, StorageMapReadAccess, StorageMapWriteAccess,
    StoragePath, StoragePathEntry, StoragePointerReadAccess, Vec, VecTrait,
};
use crate::ability::{AbilityTypes, IAbilities, SignedAbilities};
use crate::signed::Signed;
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
#[beacon_entity]
#[derive(Drop, Serde, Default, Introspect)]
pub struct Attack {
    pub speed: u8,
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

#[derive(Drop, Serde)]
pub struct AttackInput {
    pub name: ByteArray,
    pub speed: u8,
    pub accuracy: u8,
    pub cooldown: u8,
    pub hit: Array<EffectInput>,
    pub miss: Array<EffectInput>,
}

/// Represents an effect that can be applied during the game.
///
/// # Arguments
/// * `target` - Specifies who receives the effect (Player or Opponent)
/// * `affect` - The type of effect to be applied

#[derive(Drop, Serde, PartialEq, Introspect, starknet::Store)]
pub struct Effect {
    target: Target,
    affect: Affect,
}

#[derive(Copy, Drop, Serde, PartialEq)]
pub struct EffectInput {
    target: Target,
    affect: AffectInput,
}


#[derive(Drop, Serde, Copy, PartialEq, Introspect, Default, starknet::Store)]
pub enum Target {
    #[default]
    Player,
    Opponent,
}

/// Represents different types of effects that can be applied in the game
/// * `Abilities` - Multiple ability modifications applied at once using SignedAbilities
/// * `Ability` - A single ability modification using AbilityInput
/// * `Damage` - Direct damage effect
/// * `Stun` - Stun chance increase of target on next attack in percentage
/// * `Health` - Health modification (can be positive for healing or negative for damage)

#[derive(Copy, Drop, Serde, PartialEq)]
pub enum AffectInput {
    Health: Signed<u8>,
    Abilities: SignedAbilities,
    Ability: AbilityAffectInput,
    Damage: Damage,
    Stun: u8,
}

#[derive(Drop, Serde, Copy, PartialEq, Introspect, Default, starknet::Store)]
pub enum Affect {
    #[default]
    Health: i16,
    Abilities: IAbilities,
    Ability: AbilityAffect,
    Damage: Damage,
    Stun: u8,
}


/// Represents a modifier to a ability in the game.
/// * `ability` - The type of abilityistic (Strength, Vitality, Dexterity, Luck)
/// * `amount` - The numerical value of the ability, ranging from -100 to +100

#[derive(Drop, Serde, Copy, PartialEq, Introspect, starknet::Store)]
pub struct AbilityAffect {
    ability: AbilityTypes,
    amount: i32,
}

#[derive(Drop, Serde, Copy, PartialEq)]
pub struct AbilityAffectInput {
    ability: AbilityTypes,
    amount: Signed<u8>,
}


/// Represents damage attributes of an attack.
/// * `critical` - Critical hit chance value between 0-100
/// * `power` - Attack power value between 0-100

#[derive(Drop, Serde, Copy, PartialEq, Introspect, starknet::Store)]
pub struct Damage {
    critical: u32,
    power: u32,
}

#[derive(Drop, Serde, Introspect)]
pub struct AttackExists {
    hit: u32,
    miss: u32,
}

pub fn get_attack_id(
    name: @ByteArray,
    speed: u8,
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

pub impl InputIntoAffect of Into<AffectInput, Affect> {
    fn into(self: AffectInput) -> Affect {
        match self {
            AffectInput::Abilities(abilities) => Affect::Abilities(abilities.into()),
            AffectInput::Ability(ability) => Affect::Ability(
                AbilityAffect { ability: ability.ability, amount: ability.amount.into() },
            ),
            AffectInput::Damage(damage) => Affect::Damage(damage),
            AffectInput::Stun(stun) => Affect::Stun(stun),
            AffectInput::Health(health) => Affect::Health(health.into()),
        }
    }
}

pub impl InputIntoEffect of Into<EffectInput, Effect> {
    fn into(self: EffectInput) -> Effect {
        Effect { target: self.target, affect: self.affect.into() }
    }
}

pub impl InputIntoEffectArray of Into<Array<EffectInput>, Array<Effect>> {
    fn into(mut self: Array<EffectInput>) -> Array<Effect> {
        let mut effects = array![];
        loop {
            match self.pop_front() {
                Option::Some(effect) => { effects.append(effect.into()); },
                Option::None => { break; },
            };
        }
        effects
    }
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
