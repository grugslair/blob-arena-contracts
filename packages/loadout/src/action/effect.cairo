use ba_utils::storage::ShortArrayStore;
use ba_utils::{BoolIntoU8, storage};
use sai_packing::shifts::*;
use sai_packing::{
    BytePacking, MaskDowncast, SHIFT_16B_FELT252, SHIFT_18B_FELT252, SHIFT_2B, ShiftCast,
};
use starknet::storage_access::StorePacking;

const INSTANT_N: u32 = 0;
const ROUND_N: u32 = 1;
const ROUNDS_N: u32 = 2;
const INFINITE_N: u32 = 3;

const ACTOR_N: u16 = 0;
const TARGET_N: u16 = 1;

const HEALTH_PACKING_BITS: felt252 = 1 * SHIFT_16B_FELT252;
const HEALTH_MAX_PERCENT_PACKING_BITS: felt252 = 2 * SHIFT_16B_FELT252;
const STUN_PACKING_BITS: felt252 = 100 * SHIFT_16B_FELT252;
const STUN_MODIFIER_PACKING_BITS: felt252 = 101 * SHIFT_16B_FELT252;
const STUN_MODIFIER_TEMP_PACKING_BITS: felt252 = 102 * SHIFT_16B_FELT252;
const ABILITIES_PACKING_BITS: felt252 = 200 * SHIFT_16B_FELT252;
const ABILITIES_TEMP_PACKING_BITS: felt252 = 201 * SHIFT_16B_FELT252;
const DAMAGE_MODIFIERS_PACKING_BITS: felt252 = 301 * SHIFT_16B_FELT252;
const DAMAGE_MODIFIERS_TEMP_PACKING_BITS: felt252 = 302 * SHIFT_16B_FELT252;
const DAMAGE_MODIFIERS_SET_PACKING_BITS: felt252 = 303 * SHIFT_16B_FELT252;
const DAMAGE_MODIFIERS_SET_TEMP_PACKING_BITS: felt252 = 304 * SHIFT_16B_FELT252;
const DAMAGE_PACKING_BITS: felt252 = 400 * SHIFT_16B_FELT252;

const D_TYPE_BLUDGEON_N: u128 = 1;
const D_TYPE_MAGIC_N: u128 = 2;
const D_TYPE_PIERCE_N: u128 = 3;

const ROUND_PACKING_BITS: felt252 = ROUND_N.into() * SHIFT_20B_FELT252;
const ROUNDS_PACKING_BITS: felt252 = ROUNDS_N.into() * SHIFT_20B_FELT252;
const INFINITE_PACKING_BITS: felt252 = INFINITE_N.into() * SHIFT_20B_FELT252;

const ACTOR_PACKING_BITS: felt252 = ACTOR_N.into() * SHIFT_18B_FELT252;
const TARGET_PACKING_BITS: felt252 = TARGET_N.into() * SHIFT_18B_FELT252;

const D_TYPE_BLUDGEON_PACKING_BITS: u128 = D_TYPE_BLUDGEON_N * SHIFT_2B_U128;
const D_TYPE_MAGIC_PACKING_BITS: u128 = D_TYPE_MAGIC_N * SHIFT_2B_U128;
const D_TYPE_PIERCE_PACKING_BITS: u128 = D_TYPE_PIERCE_N * SHIFT_2B_U128;

/// Represents the different types of effects that can be applied to combatants
///
/// # Variants
/// ## Basic Effects
/// * `None` - No effect is applied
/// * `Health` - Modifies health by the specified amount (positive for healing, negative for damage)
/// * `Stun` - Applies stun effect for the specified number of turns
/// * `Block` - Applies block effect with the specified strength
/// * `Damage` - Deals damage with specified power, critical chance, and damage type
///
/// ## Permanent Attribute Modifications
/// * `Strength` - Permanently modifies strength attribute
/// * `Vitality` - Permanently modifies vitality attribute
/// * `Dexterity` - Permanently modifies dexterity attribute
/// * `Luck` - Permanently modifies luck attribute
/// * `Abilities` - Modifies multiple ability scores simultaneously
///
/// ## Permanent Resistance/Vulnerability Modifications
/// * `StunResistance` - Permanently modifies stun resistance
/// * `BludgeonResistance` - Permanently modifies bludgeon damage resistance
/// * `MagicResistance` - Permanently modifies magic damage resistance
/// * `PierceResistance` - Permanently modifies pierce damage resistance
/// * `BludgeonVulnerability` - Permanently modifies bludgeon damage vulnerability
/// * `MagicVulnerability` - Permanently modifies magic damage vulnerability
/// * `PierceVulnerability` - Permanently modifies pierce damage vulnerability
/// * `Resistances` - Modifies multiple resistances simultaneously
/// * `Vulnerabilities` - Modifies multiple vulnerabilities simultaneously
///
/// ## Temporary Attribute Modifications (Duration-based)
/// * `StrengthTemp` - Temporarily modifies strength attribute
/// * `VitalityTemp` - Temporarily modifies vitality attribute
/// * `DexterityTemp` - Temporarily modifies dexterity attribute
/// * `LuckTemp` - Temporarily modifies luck attribute
/// * `AbilitiesTemp` - Temporarily modifies multiple ability scores
///
/// ## Temporary Resistance/Vulnerability Modifications (Duration-based)
/// * `StunResistanceTemp` - Temporarily modifies stun resistance
/// * `BludgeonResistanceTemp` - Temporarily modifies bludgeon resistance
/// * `MagicResistanceTemp` - Temporarily modifies magic resistance
/// * `PierceResistanceTemp` - Temporarily modifies pierce resistance
/// * `BludgeonVulnerabilityTemp` - Temporarily modifies bludgeon vulnerability
/// * `MagicVulnerabilityTemp` - Temporarily modifies magic vulnerability
/// * `PierceVulnerabilityTemp` - Temporarily modifies pierce vulnerability
/// * `ResistancesTemp` - Temporarily modifies multiple resistances
/// * `VulnerabilitiesTemp` - Temporarily modifies multiple vulnerabilities
///
/// ## Health Manipulation Effects
/// * `SetHealth` - Sets health to a specific value
/// * `FloorHealth` - Sets health to minimum of current or specified value
/// * `CeilHealth` - Sets health to maximum of current or specified value
/// * `HealthPercentMax` - Modifies health by percentage of max health (can be negative)
/// * `SetHealthPercentMax` - Sets health to percentage of max health
/// * `FloorHealthPercentMax` - Sets health to minimum of current or percentage of max
/// * `CeilHealthPercentMax` - Sets health to maximum of current or percentage of max

#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
pub enum Affect {
    Health: HealthMod<u16>,
    HealthMaxPercent: HealthMod<u8>,
    Stun: u8,
    StunModifier: u16,
    StunModifierTemp: u16,
    Abilities: Abilities,
    AbilitiesTemp: Abilities,
    DamageModifiers: Modifiers,
    DamageModifiersTemp: Modifiers,
    Damage: Damage,
}


/// Specifies the target of an effect
///
/// # Variants
/// * `Actor` - The effect targets the entity that initiated the action
/// * `Target` - The effect targets the entity that is receiving the action
#[derive(Drop, Serde, Copy, PartialEq, Introspect)]
pub enum Recipient {
    Actor,
    Target,
}

/// Defines how long an effect lasts
///
/// # Variants
/// * `Instant` - The effect is applied immediately and has no duration
/// * `Round` - The effect happens on a specific round (number after the current round)
/// * `Rounds` - The effect lasts for a specific number of rounds starting next round
/// * `Infinite` - The effect lasts for the entire duration of the combat
#[derive(Drop, Serde, Copy, PartialEq, Introspect, Default)]
pub enum Duration {
    #[default]
    Instant,
    Round: u32,
    Rounds: u32,
    Infinite,
}

/// Represents an effect that can be applied during combat
///
/// # Fields
/// * `target` - Specifies who receives the effect (Actor or Target)
/// * `duration` - How long the effect lasts (Instant, Round(s), or Infinite)
/// * `affect` - The specific type of effect to be applied and its parameters
#[derive(Drop, Serde, Copy, PartialEq, Introspect)]
pub struct Effect {
    pub target: Recipient,
    pub duration: Duration,
    pub affect: Affect,
}


#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
pub enum HealthModType {
    Add,
    Subtract,
    Set,
    Floor,
    Ceil,
}

#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
pub struct HealthMod<T> {
    pub mod_type: HealthModType,
    pub value: T,
}

impl ModDefault<T, +Default<T>> of Default<HealthMod<T>> {
    fn default() -> HealthMod<T> {
        HealthMod { mod_type: HealthModType::Add, value: Default::default() }
    }
}


#[derive(Copy, Drop, Serde, PartialEq, Default, Introspect)]
pub struct Abilities {
    pub strength: i16,
    pub vitality: i16,
    pub dexterity: i16,
    pub luck: i16,
}

#[derive(Copy, Drop, Serde, PartialEq, Default, Introspect)]
pub struct Modifiers {
    pub bludgeon: u32,
    pub magic: u32,
    pub pierce: u32,
    pub all_types: u32,
}

#[derive(Copy, Drop, Serde, PartialEq, Default, Introspect)]
pub struct SetModifier {
    value: u32,
    bludgeon: bool,
    magic: bool,
    pierce: bool,
    all_types: bool,
}


impl AbilitiesPacking of StorePacking<Abilities, u128> {
    fn pack(value: Abilities) -> u128 {
        BytePacking::<_, u64>::pack([value.strength, value.vitality, value.dexterity, value.luck])
            .into()
    }

    fn unpack(value: u128) -> Abilities {
        let [strength, vitality, dexterity, luck] = BytePacking::<
            _, u64,
        >::unpack(value.try_into().unwrap());
        Abilities { strength, vitality, dexterity, luck }
    }
}


impl ModifiersPacking of StorePacking<Modifiers, u128> {
    fn pack(value: Modifiers) -> u128 {
        BytePacking::pack([value.bludgeon, value.magic, value.pierce, value.all_types])
    }

    fn unpack(value: u128) -> Modifiers {
        let [bludgeon, magic, pierce, all_types] = BytePacking::unpack(value);
        Modifiers { bludgeon, magic, pierce, all_types }
    }
}

impl SetModifierPacking of StorePacking<SetModifier, u128> {
    fn pack(value: SetModifier) -> u128 {
        BytePacking::<
            [u8; 4], u32,
        >::pack(
            [
                value.bludgeon.into(), value.magic.into(), value.pierce.into(),
                value.all_types.into(),
            ],
        )
            .into()
            + ShiftCast::const_cast::<SHIFT_4B>(value.value)
    }

    fn unpack(value: u128) -> SetModifier {
        let [bludgeon, magic, pierce, all_types] = BytePacking::<
            [u8; 4], u32,
        >::unpack(MaskDowncast::cast(value));
        SetModifier {
            value: ShiftCast::const_unpack::<SHIFT_4B>(value),
            bludgeon: bludgeon != 0,
            magic: magic != 0,
            pierce: pierce != 0,
            all_types: all_types != 0,
        }
    }
}


impl EffectStorePacking of StorePacking<Effect, felt252> {
    fn pack(value: Effect) -> felt252 {
        StorePacking::pack(value.affect)
            + match value.target {
                Recipient::Actor => ACTOR_PACKING_BITS,
                Recipient::Target => TARGET_PACKING_BITS,
            }
            + match value.duration {
                Duration::Instant => 0,
                Duration::Round(rounds) => rounds.into() * SHIFT_22B_FELT252 + ROUND_PACKING_BITS,
                Duration::Rounds(rounds) => rounds.into() * SHIFT_22B_FELT252 + ROUNDS_PACKING_BITS,
                Duration::Infinite => INFINITE_PACKING_BITS,
            }
    }

    fn unpack(value: felt252) -> Effect {
        let u256 { low, high } = value.into();
        let variant: u16 = MaskDowncast::cast(high);
        let target = match ShiftCast::const_unpack::<SHIFT_2B>(high) {
            0_u16 => Recipient::Actor,
            1_u16 => Recipient::Target,
            _ => panic!("Invalid value for Recipient"),
        };
        let duration = match ShiftCast::const_unpack::<SHIFT_4B>(high) {
            0_u16 => Duration::Instant,
            1_u16 => Duration::Round(ShiftCast::const_unpack::<SHIFT_6B>(high)),
            2_u16 => Duration::Rounds(ShiftCast::const_unpack::<SHIFT_6B>(high)),
            3_u16 => Duration::Infinite,
            _ => panic!("Invalid value for Duration"),
        };

        Effect { target, affect: unpack_affect(variant, low), duration }
    }
}


impl ModTPacking<T, +ShiftCast<T, u128, u64>, +Drop<T>> of StorePacking<HealthMod<T>, u128> {
    fn pack(value: HealthMod<T>) -> u128 {
        match value.mod_type {
            HealthModType::Add => 0_u128,
            HealthModType::Subtract => 1_u128,
            HealthModType::Set => 2_u128,
            HealthModType::Floor => 3_u128,
            HealthModType::Ceil => 4_u128,
        }
            + ShiftCast::const_cast::<SHIFT_4B>(value.value)
    }

    fn unpack(value: u128) -> HealthMod<T> {
        let mod_type = match MaskDowncast::cast(value) {
            0_u16 => HealthModType::Add,
            1_u16 => HealthModType::Subtract,
            2_u16 => HealthModType::Set,
            3_u16 => HealthModType::Floor,
            4_u16 => HealthModType::Ceil,
            _ => panic!("Invalid value for ModType"),
        };
        HealthMod { mod_type, value: ShiftCast::const_unpack::<SHIFT_4B>(value) }
    }
}


pub fn unpack_affect(variant: u16, data: u128) -> Affect {
    match variant {
        1 => Affect::Health(StorePacking::unpack(data)),
        2 => Affect::HealthMaxPercent(StorePacking::unpack(data)),
        100 => Affect::Stun(MaskDowncast::cast(data)),
        101 => Affect::StunModifier(MaskDowncast::cast(data)),
        102 => Affect::StunModifierTemp(MaskDowncast::cast(data)),
        200 => Affect::Abilities(StorePacking::unpack(data)),
        201 => Affect::AbilitiesTemp(StorePacking::unpack(data)),
        301 => Affect::DamageModifiers(StorePacking::unpack(data)),
        302 => Affect::DamageModifiersTemp(StorePacking::unpack(data)),
        400 => Affect::Damage(StorePacking::unpack(data)),
        _ => panic!("Invalid value for Affect"),
    }
}

pub fn pack_affect(value: Affect) -> (u128, felt252) {
    match value {
        Affect::Health(mod_val) => (StorePacking::pack(mod_val), HEALTH_PACKING_BITS),
        Affect::HealthMaxPercent(mod_val) => (
            StorePacking::pack(mod_val), HEALTH_MAX_PERCENT_PACKING_BITS,
        ),
        Affect::Stun(val) => (val.into(), STUN_PACKING_BITS),
        Affect::StunModifier(val) => (val.into(), STUN_MODIFIER_PACKING_BITS),
        Affect::StunModifierTemp(val) => (val.into(), STUN_MODIFIER_TEMP_PACKING_BITS),
        Affect::Abilities(val) => (StorePacking::pack(val), ABILITIES_PACKING_BITS),
        Affect::AbilitiesTemp(val) => (StorePacking::pack(val), ABILITIES_TEMP_PACKING_BITS),
        Affect::DamageModifiers(val) => (StorePacking::pack(val), DAMAGE_MODIFIERS_PACKING_BITS),
        Affect::DamageModifiersTemp(val) => (
            StorePacking::pack(val), DAMAGE_MODIFIERS_TEMP_PACKING_BITS,
        ),
        Affect::Damage(val) => (StorePacking::pack(val), DAMAGE_PACKING_BITS),
    }
}

impl AffectStorePacking of StorePacking<Affect, felt252> {
    fn pack(value: Affect) -> felt252 {
        let (data, variant): (u128, felt252) = pack_affect(value);
        data.into() + variant
    }

    fn unpack(value: felt252) -> Affect {
        let u256 { low, high } = value.into();
        unpack_affect(MaskDowncast::cast(high), low)
    }
}


/// Represents the different types of damage that can be dealt
///
/// # Variants
/// * `None` - No specific damage type (pure damage)
/// * `Bludgeon` - Physical blunt force damage (affected by bludgeon resistance/vulnerability)
/// * `Magic` - Magical damage (affected by magic resistance/vulnerability)
/// * `Pierce` - Piercing physical damage (affected by pierce resistance/vulnerability)
#[derive(Copy, Drop, Serde, PartialEq, Default, Introspect)]
pub enum DamageType {
    #[default]
    None,
    Bludgeon,
    Magic,
    Pierce,
}

/// Represents the damage characteristics of an action
///
/// # Fields
/// * `critical` - Critical hit chance as a percentage (0-100)
/// * `power` - Base damage power as a percentage (0-100)
/// * `damage_type` - The type of damage being dealt (affects resistance calculations)
#[derive(Drop, Serde, Copy, PartialEq, Introspect)]
pub struct Damage {
    pub critical: u8,
    pub power: u8,
    pub damage_type: DamageType,
}

impl DamageStorePacking of StorePacking<Damage, u128> {
    fn pack(value: Damage) -> u128 {
        value.critical.into()
            + ShiftCast::const_cast::<SHIFT_1B>(value.power)
            + match value.damage_type {
                DamageType::None => 0,
                DamageType::Bludgeon => D_TYPE_BLUDGEON_PACKING_BITS,
                DamageType::Magic => D_TYPE_MAGIC_PACKING_BITS,
                DamageType::Pierce => D_TYPE_PIERCE_PACKING_BITS,
            }
    }

    fn unpack(value: u128) -> Damage {
        let critical: u8 = MaskDowncast::cast(value);
        let power: u8 = ShiftCast::const_unpack::<SHIFT_1B>(value);
        let damage_type = match ShiftCast::const_unpack::<SHIFT_2B_U32>(value) {
            0_u16 => DamageType::None,
            1_u16 => DamageType::Bludgeon,
            2_u16 => DamageType::Magic,
            3_u16 => DamageType::Pierce,
            _ => panic!("Invalid value for DamageType"),
        };
        Damage { critical, power, damage_type }
    }
}

pub fn pack_effect_array(effects: Array<Effect>) -> Array<felt252> {
    effects.into_iter().map(|effect| EffectStorePacking::pack(effect)).collect()
}

pub fn unpack_effect_array(data: Array<felt252>) -> Array<Effect> {
    data.into_iter().map(|felt| EffectStorePacking::unpack(felt)).collect()
}


pub impl EffectArrayStorePacking of StorePacking<Array<Effect>, Array<felt252>> {
    fn pack(value: Array<Effect>) -> Array<felt252> {
        pack_effect_array(value)
    }

    fn unpack(value: Array<felt252>) -> Array<Effect> {
        unpack_effect_array(value)
    }
}

pub impl EffectArrayReadWrite = storage::short_array::ShortArrayReadWrite<Effect>;

