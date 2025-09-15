
use sai_packing::shifts::SHIFT_16B_FELT252;

const STRENGTH_N: u32 = 1;
const VITALITY_N: u32 = STRENGTH_N + 1;
const DEXTERITY_N: u32 = VITALITY_N + 1;
const LUCK_N: u32 = DEXTERITY_N + 1;
const ATTRIBUTES_N: u32 = LUCK_N + 1;
const BLUDGEON_RES_N: u32 = ATTRIBUTES_N + 1;
const MAGIC_RES_N: u32 = BLUDGEON_RES_N + 1;
const PIERCE_RES_N: u32 = MAGIC_RES_N + 1;
const RESISTANCES_N: u32 = PIERCE_RES_N + 1;
const BLUDGEON_VUL_N: u32 = RESISTANCES_N + 1;
const MAGIC_VUL_N: u32 = BLUDGEON_VUL_N + 1;
const PIERCE_VUL_N: u32 = MAGIC_VUL_N + 1;


const STRENGTH_PACKING_BITS: felt252 = STRENGTH_N.into() * SHIFT_16B_FELT252;
const VITALITY_PACKING_BITS: felt252 = VITALITY_N.into() * SHIFT_16B_FELT252;
const DEXTERITY_PACKING_BITS: felt252 = DEXTERITY_N.into() * SHIFT_16B_FELT252;
const LUCK_PACKING_BITS: felt252 = LUCK_N.into() * SHIFT_16B_FELT252;
const ATTRIBUTES_PACKING_BITS: felt252 = ATTRIBUTES_N.into() * SHIFT_16B_FELT252;
const BLUDGEON_RES_PACKING_BITS: felt252 = BLUDGEON_RES_N.into() * SHIFT_16B_FELT252;
const MAGIC_RES_PACKING_BITS: felt252 = MAGIC_RES_N.into() * SHIFT_16B_FELT252;
const PIERCE_RES_PACKING_BITS: felt252 = PIERCE_RES_N.into() * SHIFT_16B_FELT252;
const RESISTANCES_PACKING_BITS: felt252 = RESISTANCES_N.into() * SHIFT_16B_FELT252;
const BLUDGEON_VUL_PACKING_BITS: felt252 = BLUDGEON_VUL_N.into() * SHIFT_16B_FELT252;
const MAGIC_VUL_PACKING_BITS: felt252 = MAGIC_VUL_N.into() * SHIFT_16B_FELT252;
const PIERCE_VUL_PACKING_BITS: felt252 = PIERCE_VUL_N.into() * SHIFT_16B_FELT252;
const ABILITIES_PACKING_BITS: felt252 = PIERCE_VUL_N.into() * SHIFT_16B_FELT252;

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
    Abilities: Abilities,
    Resistances: Resistances,
    Vulnerabilities: Vulnerabilities,
}



impl AbilityEffectStorePacking of StorePacking<AbilityEffect, felt252> {
    fn pack(value: AbilityEffect) -> felt252 {
        let (amount, variant) = match value {
            AbilityEffect::None => { return 0; },
            AbilityEffect::Strength(amount) => (amount, STRENGTH_PACKING_BITS),
            AbilityEffect::Vitality(amount) => (amount, VITALITY_PACKING_BITS),
            AbilityEffect::Dexterity(amount) => (amount, DEXTERITY_PACKING_BITS),
            AbilityEffect::Luck(amount) => (amount, LUCK_PACKING_BITS),
            
            AbilityEffect::BludgeonResistance(amount) => (amount, BLUDGEON_RES_PACKING_BITS),
            AbilityEffect::MagicResistance(amount) => (amount, MAGIC_RES_PACKING_BITS),
            AbilityEffect::PierceResistance(amount) => (amount, PIERCE_RES_PACKING_BITS),
            AbilityEffect::BludgeonVulnerability(amount) => (amount, BLUDGEON_VUL_PACKING_BITS),
            AbilityEffect::MagicVulnerability(amount) => (amount, MAGIC_VUL_PACKING_BITS),
            AbilityEffect::PierceVulnerability(amount) => (amount, PIERCE_VUL_PACKING_BITS),
        };
        IntPacking::pack(amount).into() + variant
    }

    fn unpack(value: felt252) -> AbilityEffect {
        if value < STRENGTH_PACKING_BITS {
            return AbilityEffect::None;
        }

        let variant: u16 = ShiftCast::unpack::<SHIFT_2B>(value);
        let amount: i16 = MaskDowncast::cast(value);

        match variant {
            0 => AbilityEffect::None,
            1 => AbilityEffect::Strength(amount),
            2 => AbilityEffect::Vitality(amount),
            3 => AbilityEffect::Dexterity(amount),
            4 => AbilityEffect::Luck(amount),
            5 => AbilityEffect::Abilities()
            6 => AbilityEffect::BludgeonResistance(amount),
            7 => AbilityEffect::MagicResistance(amount),
            8 => AbilityEffect::PierceResistance(amount),
            9 => AbilityEffect::BludgeonVulnerability(amount),
            10 =>AbilityEffect::MagicVulnerability(amount), 
            11 =>AbilityEffect::PierceVulnerability(amount),
            12 =>
            _ => panic!("Invalid value for AbilityEffect"),
        }
    }
}