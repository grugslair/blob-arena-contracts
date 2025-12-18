use ba_utils::CapInto;
use core::num::traits::{Pow, SaturatingAdd, WideMul};
use core::ops::AddAssign;
use sai_core_utils::SaturatingInto;
use sai_packing::masks::*;
use sai_packing::shifts::*;
use sai_packing::{MaskDowncast, ShiftCast};
use starknet::storage_access::StorePacking;

pub const MAX_ABILITY_VALUE: u16 = 16384;
pub const MIN_ABILITY_TEMP_VALUE: i16 = -16384;
pub const MAX_MODIFIER: u32 = 2_u32.pow(28);
pub const STUN_MODIFIER_SCALE: u32 = 128;
pub const MODIFIER_SCALE_U32_U32: u32 = 2_u32.pow(14);
pub const MODIFIER_SCALE_U32_U64: u64 = 2_u64.pow(14);
pub const MODIFIER_SCALE_U128: u256 = 2_u256.pow(64);
pub const MODIFIER_U32_TO_U128: u128 = 2_u128.pow(50);
pub const MODIFIER_SCALE_4_U32: u128 = 2_u128.pow(42);

pub fn combine_partial_attributes(base: Attributes, items: Array<PartialAttributes>) -> Attributes {
    let mut calc = base.into();
    for item in items {
        calc += item;
    }
    calc.finalize()
}

pub fn combine_stun_modifiers(value: u16, change: u16) -> u16 {
    (value.wide_mul(change) / STUN_MODIFIER_SCALE).cap_into(MAX_ABILITY_VALUE)
}


pub fn combine_modifiers_u32(value: u32, change: u32) -> u32 {
    (value.wide_mul(change) / MODIFIER_SCALE_U32_U64).cap_into(MAX_MODIFIER)
}

pub fn combine_modifiers_u128(value: u128, change: u128) -> u128 {
    (value.wide_mul(change) / MODIFIER_SCALE_U128).saturating_into()
}

pub fn combine_4_modifiers_u32(m1: u32, m2: u32, m3: u32, m4: u32) -> u32 {
    (m1.wide_mul(m2).wide_mul(m3.wide_mul(m4)) / MODIFIER_SCALE_4_U32).cap_into(MAX_MODIFIER)
}


pub fn convert_u32_modifier_to_u128(value: u32) -> u128 {
    (value.into() * MODIFIER_U32_TO_U128)
}

pub fn convert_u128_modifier_to_u32(value: u128) -> u32 {
    (value / MODIFIER_U32_TO_U128).cap_into(MAX_MODIFIER)
}


/// Represents the complete set of attributes for a combatant
///
/// # Fields
/// ## Core Abilities - 0 to 65535
/// * `strength` - Strength
/// * `vitality` - Vitality
/// * `dexterity` - Dexterity
/// * `luck` - Luck
/// ## Modifiers - 2^-16 to 2^15 Scaled by 2^16
/// * `stun_modifier` - Stun modifier.
/// * `bludgeon_modifier` - Bludgeon damage modifier
/// * `magic_modifier` - Magic damage modifier
/// * `pierce_modifier` - Pierce damage modifier
/// * `damage_modifier` - Overall damage modifier
#[derive(Copy, Drop, Serde, PartialEq, Default, Introspect)]
pub struct Attributes {
    pub strength: u16,
    pub vitality: u16,
    pub dexterity: u16,
    pub luck: u16,
    pub stun_modifier: u16,
    pub bludgeon_modifier: u32,
    pub magic_modifier: u32,
    pub pierce_modifier: u32,
    pub damage_modifier: u32,
}

/// Represents a partial set of attributes, typically from items or buffs
///
/// that can be applied to a full Attributes set.
/// # Fields
/// ## Core Abilities -65536 to 65535
/// * `strength` - Strength
/// * `vitality` - Vitality
/// * `dexterity` - Dexterity
/// * `luck` - Luck
/// ## Modifiers - 2^-16 to 2^15 Scaled by 2^16
/// * `stun_modifier` - Stun modifier.
/// * `bludgeon_modifier` - Bludgeon damage modifier
/// * `magic_modifier` - Magic damage modifier
/// * `pierce_modifier` - Pierce damage modifier
/// * `damage_modifier` - Overall damage modifier

#[derive(Copy, Drop, Serde, Default, PartialEq, Introspect)]
pub struct PartialAttributes {
    pub strength: i16,
    pub vitality: i16,
    pub dexterity: i16,
    pub luck: i16,
    pub stun_modifier: u32,
    pub bludgeon_modifier: u32,
    pub magic_modifier: u32,
    pub pierce_modifier: u32,
    pub damage_modifier: u32,
}

/// Internal calculation struct for combining and processing attributes
///
/// Uses wider integer types to prevent overflow during calculations.
/// Should be finalized to Attributes before use.
///
/// # Fields
/// * `strength` - Strength value during calculation (i32 for overflow safety)
/// * `vitality` - Vitality value during calculation (i32 for overflow safety)
/// * `dexterity` - Dexterity value during calculation (i32 for overflow safety)
/// * `luck` - Luck value during calculation (i32 for overflow safety)
/// * `stun_modifier` - Stun modifier during calculation (u64 for overflow safety)
/// * `damage_modifier` - Overall damage modifier during calculation (u64 for overflow safety)
/// * `bludgeon_modifier` - Bludgeon damage modifier during calculation (u64 for overflow safety)
/// * `magic_modifier` - Magic damage modifier during calculation (u64 for overflow safety)
/// * `pierce_modifier` - Pierce damage modifier during calculation (u64 for overflow safety)
#[derive(Copy, Drop, Default, Introspect)]
pub struct AttributesCalc {
    pub strength: i128,
    pub vitality: i128,
    pub dexterity: i128,
    pub luck: i128,
    pub stun_modifier: u128,
    pub bludgeon_modifier: u128,
    pub magic_modifier: u128,
    pub pierce_modifier: u128,
    pub damage_modifier: u128,
}


impl AddAttributesCalc of Add<AttributesCalc> {
    fn add(lhs: AttributesCalc, rhs: AttributesCalc) -> AttributesCalc {
        AttributesCalc {
            strength: lhs.strength.saturating_add(rhs.strength),
            vitality: lhs.vitality.saturating_add(rhs.vitality),
            dexterity: lhs.dexterity.saturating_add(rhs.dexterity),
            luck: lhs.luck.saturating_add(rhs.luck),
            stun_modifier: combine_modifiers_u128(lhs.stun_modifier, rhs.stun_modifier),
            bludgeon_modifier: combine_modifiers_u128(lhs.bludgeon_modifier, rhs.bludgeon_modifier),
            magic_modifier: combine_modifiers_u128(lhs.magic_modifier, rhs.magic_modifier),
            pierce_modifier: combine_modifiers_u128(lhs.pierce_modifier, rhs.pierce_modifier),
            damage_modifier: combine_modifiers_u128(lhs.damage_modifier, rhs.damage_modifier),
        }
    }
}

impl AddAssignAttributesCalc of AddAssign<AttributesCalc, AttributesCalc> {
    fn add_assign(ref self: AttributesCalc, rhs: AttributesCalc) {
        self = self + rhs;
    }
}

impl AddAssignPartialAttributesCalc of AddAssign<AttributesCalc, PartialAttributes> {
    fn add_assign(ref self: AttributesCalc, rhs: PartialAttributes) {
        self = self + rhs.into();
    }
}

#[generate_trait]
pub impl AttributesCalcImpl of AttributesCalcTrait {
    fn finalize(self: AttributesCalc) -> Attributes {
        Attributes {
            strength: self.strength.saturating_into(),
            vitality: self.vitality.saturating_into(),
            dexterity: self.dexterity.saturating_into(),
            luck: self.luck.saturating_into(),
            stun_modifier: convert_u128_modifier_to_u32(self.stun_modifier),
            bludgeon_modifier: convert_u128_modifier_to_u32(self.bludgeon_modifier),
            magic_modifier: convert_u128_modifier_to_u32(self.magic_modifier),
            pierce_modifier: convert_u128_modifier_to_u32(self.pierce_modifier),
            damage_modifier: convert_u128_modifier_to_u32(self.damage_modifier),
        }
    }
}


#[generate_trait]
pub impl AttributesImpl of AttributesTrait {
    fn add_partial_attributes(self: Attributes, items: Array<PartialAttributes>) -> Attributes {
        combine_partial_attributes(self, items)
    }
}

impl AttributesIntoAttributesCalc of Into<Attributes, AttributesCalc> {
    fn into(self: Attributes) -> AttributesCalc {
        AttributesCalc {
            strength: self.strength.into(),
            vitality: self.vitality.into(),
            dexterity: self.dexterity.into(),
            luck: self.luck.into(),
            bludgeon_modifier: convert_u32_modifier_to_u128(self.bludgeon_modifier),
            magic_modifier: convert_u32_modifier_to_u128(self.magic_modifier),
            pierce_modifier: convert_u32_modifier_to_u128(self.pierce_modifier),
            damage_modifier: convert_u32_modifier_to_u128(self.damage_modifier),
            stun_modifier: convert_u32_modifier_to_u128(self.stun_modifier),
        }
    }
}

impl PartialAttributesIntoAttributesCalc of Into<PartialAttributes, AttributesCalc> {
    fn into(self: PartialAttributes) -> AttributesCalc {
        AttributesCalc {
            strength: self.strength.into(),
            vitality: self.vitality.into(),
            dexterity: self.dexterity.into(),
            luck: self.luck.into(),
            bludgeon_modifier: convert_u32_modifier_to_u128(self.bludgeon_modifier),
            magic_modifier: convert_u32_modifier_to_u128(self.magic_modifier),
            pierce_modifier: convert_u32_modifier_to_u128(self.pierce_modifier),
            damage_modifier: convert_u32_modifier_to_u128(self.damage_modifier),
            stun_modifier: convert_u32_modifier_to_u128(self.stun_modifier),
        }
    }
}

impl AttributesStorePacking of StorePacking<Attributes, felt252> {
    fn pack(value: Attributes) -> felt252 {
        value.strength.into()
            + SHIFT_14b_FELT252 * value.vitality.into()
            + SHIFT_28b_FELT252 * value.dexterity.into()
            + SHIFT_42b_FELT252 * value.luck.into()
            + SHIFT_56b_FELT252 * value.stun_modifier.into()
            + SHIFT_84b_FELT252 * value.bludgeon_modifier.into()
            + SHIFT_112b_FELT252 * value.magic_modifier.into()
            + SHIFT_140b_FELT252 * value.pierce_modifier.into()
            + SHIFT_168b_FELT252 * value.damage_modifier.into()
    }

    fn unpack(value: felt252) -> Attributes {
        let value: u256 = value.into();
        let u256 { low, high } = value;
        Attributes {
            strength: MaskDowncast::cast(low) & MASK_14b_U16,
            vitality: ShiftCast::const_unpack::<SHIFT_14b>(low) & MASK_14b_U16,
            dexterity: ShiftCast::const_unpack::<SHIFT_28b>(low) & MASK_14b_U16,
            luck: ShiftCast::const_unpack::<SHIFT_42b>(low) & MASK_14b_U16,
            stun_modifier: ShiftCast::const_unpack::<SHIFT_56b>(low) & MASK_28b_U32,
            bludgeon_modifier: ShiftCast::const_unpack::<SHIFT_84b>(low) & MASK_31b_U32,
            magic_modifier: ShiftCast::const_unpack::<SHIFT_112b>(value) & MASK_31b_U32,
            pierce_modifier: ShiftCast::const_unpack::<SHIFT_29b>(high) & MASK_31b_U32,
            damage_modifier: ShiftCast::const_unpack::<SHIFT_60b>(high) & MASK_31b_U32,
        }
    }
}

fn pack_partial_attribute(value: i16) -> u16 {
    if value >= 0 {
        value.try_into().unwrap()
    } else {
        SHIFT_15b_U16 + (-value).try_into().unwrap()
    }
}

fn unpack_partial_attribute(value: u16) -> i16 {
    if value < SHIFT_15b_U16 {
        value.try_into().unwrap()
    } else {
        -(value - SHIFT_15b_U16).try_into().unwrap()
    }
}

impl PartialAttributesStorePacking of StorePacking<PartialAttributes, felt252> {
    fn pack(value: PartialAttributes) -> felt252 {
        pack_partial_attribute(value.strength).into()
            + SHIFT_15b_FELT252 * pack_partial_attribute(value.vitality).into()
            + SHIFT_30b_FELT252 * pack_partial_attribute(value.dexterity).into()
            + SHIFT_45b_FELT252 * pack_partial_attribute(value.luck).into()
            + SHIFT_60b_FELT252 * value.stun_modifier.into()
            + SHIFT_88b_FELT252 * value.bludgeon_modifier.into()
            + SHIFT_106b_FELT252 * value.magic_modifier.into()
            + SHIFT_134b_FELT252 * value.pierce_modifier.into()
            + SHIFT_162b_FELT252 * value.damage_modifier.into()
    }

    fn unpack(value: felt252) -> PartialAttributes {
        let value: u256 = value.into();
        let u256 { low, high } = value;
        PartialAttributes {
            strength: unpack_partial_attribute(MaskDowncast::cast(low) & MASK_15b_U16),
            vitality: unpack_partial_attribute(
                ShiftCast::const_unpack::<SHIFT_15b>(low) & MASK_15b_U16,
            ),
            dexterity: unpack_partial_attribute(
                ShiftCast::const_unpack::<SHIFT_30b>(low) & MASK_15b_U16,
            ),
            luck: unpack_partial_attribute(
                ShiftCast::const_unpack::<SHIFT_45b>(low) & MASK_15b_U16,
            ),
            stun_modifier: ((low / SHIFT_60b_U128) & MASK_28b_U128).try_into().unwrap(),
            bludgeon_modifier: ((low / SHIFT_88b_U128) & MASK_28b_U128).try_into().unwrap(),
            magic_modifier: ((value / SHIFT_106b_U256) & MASK_28b_U256).try_into().unwrap(),
            pierce_modifier: ((high / SHIFT_6b_U128) & MASK_28b_U128).try_into().unwrap(),
            damage_modifier: ((high / SHIFT_34b_U128) & MASK_28b_U128).try_into().unwrap(),
        }
    }
}
