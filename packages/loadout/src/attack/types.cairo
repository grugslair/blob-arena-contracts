use blob_arena::core::Signed;
use blob_arena::id_trait::{IdTrait, TIdsImpl};
use sai_core_utils::poseidon_serde::PoseidonSerde;
use starknet::ContractAddress;
use crate::abilities::{AbilityTypes, IAbilities, SignedAbilities};
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

#[dojo::model]
#[derive(Drop, Serde, Default)]
struct Attack {
    speed: u8,
    accuracy: u8,
    cooldown: u8,
    hit: Array<Effect>,
    miss: Array<Effect>,
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
struct AttackInput {
    name: ByteArray,
    speed: u8,
    accuracy: u8,
    cooldown: u8,
    hit: Array<EffectInput>,
    miss: Array<EffectInput>,
}

/// Represents an effect that can be applied during the game.
///
/// # Arguments
/// * `target` - Specifies who receives the effect (Player or Opponent)
/// * `affect` - The type of effect to be applied

#[derive(Drop, Serde, PartialEq, Introspect)]
pub struct Effect {
    target: Target,
    affect: Affect,
}

#[derive(Copy, Drop, Serde, PartialEq)]
pub struct EffectInput {
    target: Target,
    affect: AffectInput,
}


#[derive(Drop, Serde, Copy, PartialEq, Introspect)]
pub enum Target {
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
    Abilities: SignedAbilities,
    Ability: AbilityAffectInput,
    Damage: Damage,
    Stun: u8,
    Health: Signed<u8>,
}

#[derive(Drop, Serde, Copy, PartialEq, Introspect)]
pub enum Affect {
    Abilities: IAbilities,
    Ability: AbilityAffect,
    Damage: Damage,
    Stun: u8,
    Health: i16,
}


/// Represents a modifier to a ability in the game.
/// * `ability` - The type of abilityistic (Strength, Vitality, Dexterity, Luck)
/// * `amount` - The numerical value of the ability, ranging from -100 to +100

#[derive(Drop, Serde, Copy, PartialEq, Introspect)]
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

#[derive(Drop, Serde, Copy, PartialEq, Introspect)]
pub struct Damage {
    critical: u32,
    power: u32,
}

#[derive(Drop, Serde, Introspect)]
pub struct AttackExists {
    hit: u32,
    miss: u32,
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

#[generate_trait]
pub impl AttackInputImpl of AttackInputTrait {
    fn to_attack_and_name(self: AttackInput, id: felt252) -> (Attack, ByteArray) {
        (
            Attack {
                id,
                speed: self.speed,
                accuracy: self.accuracy,
                cooldown: self.cooldown,
                hit: self.hit.into(),
                miss: self.miss.into(),
            },
            self.name,
        )
    }

    fn id(self: @AttackInput) -> felt252 {
        self.poseidon_hash()
    }
}


pub impl AttackIdImpl of IdTrait<Attack> {
    fn id(self: @Attack) -> felt252 {
        *(self.id)
    }
}

pub impl AttackIdsImpl = TIdsImpl<Attack>;
