use sai_packing::shifts::{SHIFT_16B, SHIFT_16B_FELT252};
use sai_packing::{IntPacking, MaskDowncast, ShiftCast};
use starknet::storage_access::StorePacking;
use crate::attributes::{Abilities, AbilityMods, ResistanceMods, VulnerabilityMods};

const STRENGTH_N: u32 = 1;
const VITALITY_N: u32 = 2;
const DEXTERITY_N: u32 = 3;
const LUCK_N: u32 = 4;
const BLUDGEON_RES_N: u32 = 5;
const MAGIC_RES_N: u32 = 6;
const PIERCE_RES_N: u32 = 7;
const BLUDGEON_VUL_N: u32 = 8;
const MAGIC_VUL_N: u32 = 9;
const PIERCE_VUL_N: u32 = 10;
const ABILITIES_N: u32 = 11;
const RESISTANCES_N: u32 = 12;
const VULNERABILITIES_N: u32 = 13;

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

#[derive(Copy, Drop, Serde, PartialEq, Default, Introspect)]
pub enum AbilityEffect {
    #[default]
    None,
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
}

impl AbilityEffectStorePacking of StorePacking<AbilityEffect, felt252> {
    fn pack(value: AbilityEffect) -> felt252 {
        let (amount, variant): (u128, felt252) = match value {
            AbilityEffect::None => { return 0; },
            AbilityEffect::Strength(amount) => (
                IntPacking::pack_into(amount), STRENGTH_PACKING_BITS,
            ),
            AbilityEffect::Vitality(amount) => (
                IntPacking::pack_into(amount), VITALITY_PACKING_BITS,
            ),
            AbilityEffect::Dexterity(amount) => (
                IntPacking::pack_into(amount), DEXTERITY_PACKING_BITS,
            ),
            AbilityEffect::Luck(amount) => (IntPacking::pack_into(amount), LUCK_PACKING_BITS),
            AbilityEffect::BludgeonResistance(amount) => (
                IntPacking::pack_into(amount), BLUDGEON_RES_PACKING_BITS,
            ),
            AbilityEffect::MagicResistance(amount) => (
                IntPacking::pack_into(amount), MAGIC_RES_PACKING_BITS,
            ),
            AbilityEffect::PierceResistance(amount) => (
                IntPacking::pack_into(amount), PIERCE_RES_PACKING_BITS,
            ),
            AbilityEffect::BludgeonVulnerability(amount) => (
                IntPacking::pack_into(amount), BLUDGEON_VUL_PACKING_BITS,
            ),
            AbilityEffect::MagicVulnerability(amount) => (
                IntPacking::pack_into(amount), MAGIC_VUL_PACKING_BITS,
            ),
            AbilityEffect::PierceVulnerability(amount) => (
                IntPacking::pack_into(amount), PIERCE_VUL_PACKING_BITS,
            ),
            AbilityEffect::Abilities(amount) => (
                StorePacking::pack(amount).into(), ABILITIES_PACKING_BITS,
            ),
        };
        amount.into() + variant
    }

    fn unpack(value: felt252) -> AbilityEffect {
        let u256 { low, high } = value.into();
        if value < STRENGTH_PACKING_BITS {
            return AbilityEffect::None;
        }

        match high {
            0 => AbilityEffect::None,
            1 => AbilityEffect::Strength(MaskDowncast::cast(value)),
            2 => AbilityEffect::Vitality(MaskDowncast::cast(value)),
            3 => AbilityEffect::Dexterity(MaskDowncast::cast(value)),
            4 => AbilityEffect::Luck(MaskDowncast::cast(value)),
            5 => AbilityEffect::BludgeonResistance(MaskDowncast::cast(value)),
            6 => AbilityEffect::MagicResistance(MaskDowncast::cast(value)),
            7 => AbilityEffect::PierceResistance(MaskDowncast::cast(value)),
            8 => AbilityEffect::BludgeonVulnerability(MaskDowncast::cast(value)),
            9 => AbilityEffect::MagicVulnerability(MaskDowncast::cast(value)),
            10 => AbilityEffect::PierceVulnerability(MaskDowncast::cast(value)),
            11 => AbilityEffect::Resistances(),
            _ => panic!("Invalid value for AbilityEffect"),
        }
    }
}
