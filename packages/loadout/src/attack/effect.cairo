use ba_utils::storage;
use ba_utils::storage::ShortArrayStore;
use sai_packing::shifts::{
    SHIFT_1B, SHIFT_20B_FELT252, SHIFT_22B_FELT252, SHIFT_2B_U32, SHIFT_4B, SHIFT_6B,
};
use sai_packing::{
    IntPacking, MaskDowncast, SHIFT_16B_FELT252, SHIFT_18B_FELT252, SHIFT_2B, ShiftCast,
};
use starknet::storage_access::StorePacking;
use crate::attributes::{AbilityMods, ResistanceMods, VulnerabilityMods};


const INSTANT_N: u32 = 0;
const ROUND_N: u32 = 1;
const ROUNDS_N: u32 = 2;
const INFINITE_N: u32 = 3;

const ATTACKER_N: u16 = 0;
const DEFENDER_N: u16 = 1;

const HEALTH_N: u32 = 1;
const STUN_N: u32 = 2;
const BLOCK_N: u32 = 3;
const STRENGTH_N: u32 = 4;
const VITALITY_N: u32 = 5;
const DEXTERITY_N: u32 = 6;
const LUCK_N: u32 = 7;
const BLUDGEON_RES_N: u32 = 8;
const MAGIC_RES_N: u32 = 9;
const PIERCE_RES_N: u32 = 10;
const BLUDGEON_VUL_N: u32 = 11;
const MAGIC_VUL_N: u32 = 12;
const PIERCE_VUL_N: u32 = 13;
const ABILITIES_N: u32 = 14;
const RESISTANCES_N: u32 = 15;
const VULNERABILITIES_N: u32 = 16;
const STRENGTH_TEMP_N: u32 = 17;
const VITALITY_TEMP_N: u32 = 18;
const DEXTERITY_TEMP_N: u32 = 19;
const LUCK_TEMP_N: u32 = 20;
const BLUDGEON_RESISTANCE_TEMP_N: u32 = 21;
const MAGIC_RESISTANCE_TEMP_N: u32 = 22;
const PIERCE_RESISTANCE_TEMP_N: u32 = 23;
const BLUDGEON_VULNERABILITY_TEMP_N: u32 = 24;
const MAGIC_VULNERABILITY_TEMP_N: u32 = 25;
const PIERCE_VULNERABILITY_TEMP_N: u32 = 26;
const ABILITIES_TEMP_N: u32 = 27;
const RESISTANCES_TEMP_N: u32 = 28;
const VULNERABILITIES_TEMP_N: u32 = 29;
const DAMAGE_N: u32 = 30;


const D_TYPE_BLUDGEON_N: u32 = 1;
const D_TYPE_MAGIC_N: u32 = 2;
const D_TYPE_PIERCE_N: u32 = 3;


const ROUND_PACKING_BITS: felt252 = ROUND_N.into() * SHIFT_20B_FELT252;
const ROUNDS_PACKING_BITS: felt252 = ROUNDS_N.into() * SHIFT_20B_FELT252;
const INFINITE_PACKING_BITS: felt252 = INFINITE_N.into() * SHIFT_20B_FELT252;

const ATTACKER_PACKING_BITS: felt252 = ATTACKER_N.into() * SHIFT_18B_FELT252;
const DEFENDER_PACKING_BITS: felt252 = DEFENDER_N.into() * SHIFT_18B_FELT252;

const STRENGTH_PACKING_BITS: felt252 = STRENGTH_N.into() * SHIFT_16B_FELT252;
const VITALITY_PACKING_BITS: felt252 = VITALITY_N.into() * SHIFT_16B_FELT252;
const DEXTERITY_PACKING_BITS: felt252 = DEXTERITY_N.into() * SHIFT_16B_FELT252;
const LUCK_PACKING_BITS: felt252 = LUCK_N.into() * SHIFT_16B_FELT252;
const BLUDGEON_RES_PACKING_BITS: felt252 = BLUDGEON_RES_N.into() * SHIFT_16B_FELT252;
const MAGIC_RES_PACKING_BITS: felt252 = MAGIC_RES_N.into() * SHIFT_16B_FELT252;
const PIERCE_RES_PACKING_BITS: felt252 = PIERCE_RES_N.into() * SHIFT_16B_FELT252;
const BLUDGEON_VUL_PACKING_BITS: felt252 = BLUDGEON_VUL_N.into() * SHIFT_16B_FELT252;
const MAGIC_VUL_PACKING_BITS: felt252 = MAGIC_VUL_N.into() * SHIFT_16B_FELT252;
const PIERCE_VUL_PACKING_BITS: felt252 = PIERCE_VUL_N.into() * SHIFT_16B_FELT252;
const ABILITIES_PACKING_BITS: felt252 = ABILITIES_N.into() * SHIFT_16B_FELT252;
const RESISTANCES_PACKING_BITS: felt252 = RESISTANCES_N.into() * SHIFT_16B_FELT252;
const VULNERABILITIES_PACKING_BITS: felt252 = VULNERABILITIES_N.into() * SHIFT_16B_FELT252;
const DAMAGE_PACKING_BITS: felt252 = DAMAGE_N.into() * SHIFT_16B_FELT252;
const STUN_PACKING_BITS: felt252 = STUN_N.into() * SHIFT_16B_FELT252;
const BLOCK_PACKING_BITS: felt252 = BLOCK_N.into() * SHIFT_16B_FELT252;
const HEALTH_PACKING_BITS: felt252 = HEALTH_N.into() * SHIFT_16B_FELT252;
const STRENGTH_TEMP_PACKING_BITS: felt252 = STRENGTH_TEMP_N.into() * SHIFT_16B_FELT252;
const VITALITY_TEMP_PACKING_BITS: felt252 = VITALITY_TEMP_N.into() * SHIFT_16B_FELT252;
const DEXTERITY_TEMP_PACKING_BITS: felt252 = DEXTERITY_TEMP_N.into() * SHIFT_16B_FELT252;
const LUCK_TEMP_PACKING_BITS: felt252 = LUCK_TEMP_N.into() * SHIFT_16B_FELT252;
const BLUDGEON_RESISTANCE_TEMP_PACKING_BITS: felt252 = BLUDGEON_RESISTANCE_TEMP_N.into()
    * SHIFT_16B_FELT252;
const MAGIC_RESISTANCE_TEMP_PACKING_BITS: felt252 = MAGIC_RESISTANCE_TEMP_N.into()
    * SHIFT_16B_FELT252;
const PIERCE_RESISTANCE_TEMP_PACKING_BITS: felt252 = PIERCE_RESISTANCE_TEMP_N.into()
    * SHIFT_16B_FELT252;
const BLUDGEON_VULNERABILITY_TEMP_PACKING_BITS: felt252 = BLUDGEON_VULNERABILITY_TEMP_N.into()
    * SHIFT_16B_FELT252;
const MAGIC_VULNERABILITY_TEMP_PACKING_BITS: felt252 = MAGIC_VULNERABILITY_TEMP_N.into()
    * SHIFT_16B_FELT252;
const PIERCE_VULNERABILITY_TEMP_PACKING_BITS: felt252 = PIERCE_VULNERABILITY_TEMP_N.into()
    * SHIFT_16B_FELT252;
const ABILITIES_TEMP_PACKING_BITS: felt252 = ABILITIES_TEMP_N.into() * SHIFT_16B_FELT252;
const RESISTANCES_TEMP_PACKING_BITS: felt252 = RESISTANCES_TEMP_N.into() * SHIFT_16B_FELT252;
const VULNERABILITIES_TEMP_PACKING_BITS: felt252 = VULNERABILITIES_TEMP_N.into()
    * SHIFT_16B_FELT252;

const D_TYPE_BLUDGEON_PACKING_BITS: u32 = D_TYPE_BLUDGEON_N * SHIFT_2B_U32;
const D_TYPE_MAGIC_PACKING_BITS: u32 = D_TYPE_MAGIC_N * SHIFT_2B_U32;
const D_TYPE_PIERCE_PACKING_BITS: u32 = D_TYPE_PIERCE_N * SHIFT_2B_U32;

#[derive(Copy, Drop, Serde, PartialEq, Default, Introspect)]
pub enum Affect {
    #[default]
    None,
    Health: i8,
    Stun: u8,
    Block: u8,
    Strength: i8,
    Vitality: i8,
    Dexterity: i8,
    Luck: i8,
    BludgeonResistance: i8,
    MagicResistance: i8,
    PierceResistance: i8,
    BludgeonVulnerability: i16,
    MagicVulnerability: i16,
    PierceVulnerability: i16,
    Abilities: AbilityMods,
    Resistances: ResistanceMods,
    Vulnerabilities: VulnerabilityMods,
    StrengthTemp: i8,
    VitalityTemp: i8,
    DexterityTemp: i8,
    LuckTemp: i8,
    BludgeonResistanceTemp: i8,
    MagicResistanceTemp: i8,
    PierceResistanceTemp: i8,
    BludgeonVulnerabilityTemp: i16,
    MagicVulnerabilityTemp: i16,
    PierceVulnerabilityTemp: i16,
    AbilitiesTemp: AbilityMods,
    ResistancesTemp: ResistanceMods,
    VulnerabilitiesTemp: VulnerabilityMods,
    Damage: Damage,
}

#[derive(Drop, Serde, Copy, PartialEq, Introspect)]
pub enum Target {
    Attacker,
    Defender,
}

#[derive(Drop, Serde, Copy, PartialEq, Introspect, Default)]
pub enum Duration {
    #[default]
    Instant,
    Round: u32,
    Rounds: u32,
    Infinite,
}

/// Represents an effect that can be applied during the game.
///
/// # Arguments
/// * `target` - Specifies who receives the effect (Player or Opponent)
/// * `affect` - The type of effect to be applied

#[derive(Drop, Serde, Copy, PartialEq, Introspect)]
pub struct Effect {
    pub target: Target,
    pub duration: Duration,
    pub affect: Affect,
}

impl EffectStorePacking of StorePacking<Effect, felt252> {
    fn pack(value: Effect) -> felt252 {
        StorePacking::pack(value.affect)
            + match value.target {
                Target::Attacker => ATTACKER_PACKING_BITS,
                Target::Defender => DEFENDER_PACKING_BITS,
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
            0_u16 => Target::Attacker,
            1_u16 => Target::Defender,
            _ => panic!("Invalid value for Target"),
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


pub fn unpack_affect(variant: u16, data: u128) -> Affect {
    match variant {
        0 => Affect::None,
        1 => Affect::Health(MaskDowncast::cast(data)),
        2 => Affect::Stun(MaskDowncast::cast(data)),
        3 => Affect::Block(MaskDowncast::cast(data)),
        4 => Affect::Strength(MaskDowncast::cast(data)),
        5 => Affect::Vitality(MaskDowncast::cast(data)),
        6 => Affect::Dexterity(MaskDowncast::cast(data)),
        7 => Affect::Luck(MaskDowncast::cast(data)),
        8 => Affect::BludgeonResistance(MaskDowncast::cast(data)),
        9 => Affect::MagicResistance(MaskDowncast::cast(data)),
        10 => Affect::PierceResistance(MaskDowncast::cast(data)),
        11 => Affect::BludgeonVulnerability(MaskDowncast::cast(data)),
        12 => Affect::MagicVulnerability(MaskDowncast::cast(data)),
        13 => Affect::PierceVulnerability(MaskDowncast::cast(data)),
        14 => Affect::Abilities(StorePacking::unpack(MaskDowncast::cast(data))),
        15 => Affect::Resistances(StorePacking::unpack(MaskDowncast::cast(data))),
        16 => Affect::Vulnerabilities(StorePacking::unpack(MaskDowncast::cast(data))),
        17 => Affect::StrengthTemp(MaskDowncast::cast(data)),
        18 => Affect::VitalityTemp(MaskDowncast::cast(data)),
        19 => Affect::DexterityTemp(MaskDowncast::cast(data)),
        20 => Affect::LuckTemp(MaskDowncast::cast(data)),
        21 => Affect::BludgeonResistanceTemp(MaskDowncast::cast(data)),
        22 => Affect::MagicResistanceTemp(MaskDowncast::cast(data)),
        23 => Affect::PierceResistanceTemp(MaskDowncast::cast(data)),
        24 => Affect::BludgeonVulnerabilityTemp(MaskDowncast::cast(data)),
        25 => Affect::MagicVulnerabilityTemp(MaskDowncast::cast(data)),
        26 => Affect::PierceVulnerabilityTemp(MaskDowncast::cast(data)),
        27 => Affect::AbilitiesTemp(StorePacking::unpack(MaskDowncast::cast(data))),
        28 => Affect::ResistancesTemp(StorePacking::unpack(MaskDowncast::cast(data))),
        29 => Affect::VulnerabilitiesTemp(StorePacking::unpack(MaskDowncast::cast(data))),
        30 => Affect::Damage(DamageStorePacking::unpack(MaskDowncast::cast(data))),
        _ => panic!("Invalid value for Affect"),
    }
}

impl AffectStorePacking of StorePacking<Affect, felt252> {
    fn pack(value: Affect) -> felt252 {
        let (amount, variant): (u128, felt252) = match value {
            Affect::None => { return 0; },
            Affect::Health(amount) => (IntPacking::pack_into(amount), HEALTH_PACKING_BITS),
            Affect::Stun(amount) => (amount.into(), STUN_PACKING_BITS),
            Affect::Block(amount) => (amount.into(), BLOCK_PACKING_BITS),
            Affect::Strength(amount) => (IntPacking::pack_into(amount), STRENGTH_PACKING_BITS),
            Affect::Vitality(amount) => (IntPacking::pack_into(amount), VITALITY_PACKING_BITS),
            Affect::Dexterity(amount) => (IntPacking::pack_into(amount), DEXTERITY_PACKING_BITS),
            Affect::Luck(amount) => (IntPacking::pack_into(amount), LUCK_PACKING_BITS),
            Affect::BludgeonResistance(amount) => (
                IntPacking::pack_into(amount), BLUDGEON_RES_PACKING_BITS,
            ),
            Affect::MagicResistance(amount) => (
                IntPacking::pack_into(amount), MAGIC_RES_PACKING_BITS,
            ),
            Affect::PierceResistance(amount) => (
                IntPacking::pack_into(amount), PIERCE_RES_PACKING_BITS,
            ),
            Affect::BludgeonVulnerability(amount) => (
                IntPacking::pack_into(amount), BLUDGEON_VUL_PACKING_BITS,
            ),
            Affect::MagicVulnerability(amount) => (
                IntPacking::pack_into(amount), MAGIC_VUL_PACKING_BITS,
            ),
            Affect::PierceVulnerability(amount) => (
                IntPacking::pack_into(amount), PIERCE_VUL_PACKING_BITS,
            ),
            Affect::Abilities(amount) => (
                StorePacking::pack(amount).into(), ABILITIES_PACKING_BITS,
            ),
            Affect::Resistances(amount) => (
                StorePacking::pack(amount).into(), RESISTANCES_PACKING_BITS,
            ),
            Affect::Vulnerabilities(amount) => (
                StorePacking::pack(amount).into(), VULNERABILITIES_PACKING_BITS,
            ),
            Affect::StrengthTemp(amount) => (
                IntPacking::pack_into(amount), STRENGTH_TEMP_PACKING_BITS,
            ),
            Affect::VitalityTemp(amount) => (
                IntPacking::pack_into(amount), VITALITY_TEMP_PACKING_BITS,
            ),
            Affect::DexterityTemp(amount) => (
                IntPacking::pack_into(amount), DEXTERITY_TEMP_PACKING_BITS,
            ),
            Affect::LuckTemp(amount) => (IntPacking::pack_into(amount), LUCK_TEMP_PACKING_BITS),
            Affect::BludgeonResistanceTemp(amount) => (
                IntPacking::pack_into(amount), BLUDGEON_RESISTANCE_TEMP_PACKING_BITS,
            ),
            Affect::MagicResistanceTemp(amount) => (
                IntPacking::pack_into(amount), MAGIC_RESISTANCE_TEMP_PACKING_BITS,
            ),
            Affect::PierceResistanceTemp(amount) => (
                IntPacking::pack_into(amount), PIERCE_RESISTANCE_TEMP_PACKING_BITS,
            ),
            Affect::BludgeonVulnerabilityTemp(amount) => (
                IntPacking::pack_into(amount), BLUDGEON_VULNERABILITY_TEMP_PACKING_BITS,
            ),
            Affect::MagicVulnerabilityTemp(amount) => (
                IntPacking::pack_into(amount), MAGIC_VULNERABILITY_TEMP_PACKING_BITS,
            ),
            Affect::PierceVulnerabilityTemp(amount) => (
                IntPacking::pack_into(amount), PIERCE_VULNERABILITY_TEMP_PACKING_BITS,
            ),
            Affect::AbilitiesTemp(amount) => (
                StorePacking::pack(amount).into(), ABILITIES_TEMP_PACKING_BITS,
            ),
            Affect::ResistancesTemp(amount) => (
                StorePacking::pack(amount).into(), RESISTANCES_TEMP_PACKING_BITS,
            ),
            Affect::VulnerabilitiesTemp(amount) => (
                StorePacking::pack(amount).into(), VULNERABILITIES_TEMP_PACKING_BITS,
            ),
            Affect::Damage(amount) => (StorePacking::pack(amount).into(), DAMAGE_PACKING_BITS),
        };
        amount.into() + variant
    }

    fn unpack(value: felt252) -> Affect {
        let u256 { low, high } = value.into();
        unpack_affect(MaskDowncast::cast(high), low)
    }
}


#[derive(Copy, Drop, Serde, PartialEq, Default, Introspect)]
pub enum DamageType {
    #[default]
    None,
    Bludgeon,
    Magic,
    Pierce,
}

/// Represents damage traits of an attack.
/// * `critical` - Critical success chance value between 0-100
/// * `power` - Attack power value between 0-100
#[derive(Drop, Serde, Copy, PartialEq, Introspect)]
pub struct Damage {
    pub critical: u8,
    pub power: u8,
    pub damage_type: DamageType,
}

impl DamageStorePacking of StorePacking<Damage, u32> {
    fn pack(value: Damage) -> u32 {
        value.critical.into()
            + ShiftCast::const_cast::<SHIFT_1B>(value.power)
            + match value.damage_type {
                DamageType::None => 0,
                DamageType::Bludgeon => D_TYPE_BLUDGEON_PACKING_BITS,
                DamageType::Magic => D_TYPE_MAGIC_PACKING_BITS,
                DamageType::Pierce => D_TYPE_PIERCE_PACKING_BITS,
            }
    }

    fn unpack(value: u32) -> Damage {
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
// fn test() {
//     let effects: Array<Effect> = Default::default();
//     let effects: Array<Effect> = Store::read(0, storage_base_address_from_felt252(0))
//         .unwrap_syscall();
// }


