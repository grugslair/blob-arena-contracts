use ba_utils::{CapInto, IntoRange};
use core::num::traits::{Pow, WideMul, Zero};
use core::ops::AddAssign;
use sai_core_utils::SaturatingInto;
use sai_packing::masks::*;
use sai_packing::shifts::*;
use sai_packing::{BytePacking, IntPacking, MaskDowncast, ShiftCast};
use starknet::storage_access::StorePacking;


pub const MAX_MODIFIER: u32 = 2147483648;
pub const MODIFIER_SCALE_U32: u64 = 65536;
pub const MODIFIER_SCALE_U64: u128 = 4294967296;
pub const MAX_STAT_VALUE: u16 = 65535;

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
    pub stun_modifier: u32,
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
    pub strength: i32,
    pub vitality: i32,
    pub dexterity: i32,
    pub luck: i32,
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
    pub strength: i32,
    pub vitality: i32,
    pub dexterity: i32,
    pub luck: i32,
    pub stun_modifier: u64,
    pub bludgeon_modifier: u64,
    pub magic_modifier: u64,
    pub pierce_modifier: u64,
    pub damage_modifier: u64,
}


impl AddAttributesCalc of Add<AttributesCalc> {
    fn add(lhs: AttributesCalc, rhs: AttributesCalc) -> AttributesCalc {
        AttributesCalc {
            strength: lhs.strength + rhs.strength,
            vitality: lhs.vitality + rhs.vitality,
            dexterity: lhs.dexterity + rhs.dexterity,
            luck: lhs.luck + rhs.luck,
            stun_modifier: increase_modifier_calc(lhs.stun_modifier, rhs.stun_modifier),
            bludgeon_modifier: increase_modifier_calc(lhs.bludgeon_modifier, rhs.bludgeon_modifier),
            magic_resistance: increase_resistance_calc(lhs.magic_resistance, rhs.magic_resistance),
            pierce_resistance: increase_resistance_calc(
                lhs.pierce_resistance, rhs.pierce_resistance,
            ),
            bludgeon_vulnerability: lhs.bludgeon_vulnerability + rhs.bludgeon_vulnerability,
            magic_vulnerability: lhs.magic_vulnerability + rhs.magic_vulnerability,
            pierce_vulnerability: lhs.pierce_vulnerability + rhs.pierce_vulnerability,
        }
    }
}

impl AddAssignAttributesCalc<Rhs, +Into<Rhs, AttributesCalc>> of AddAssign<AttributesCalc, Rhs> {
    fn add_assign(ref self: AttributesCalc, rhs: Rhs) {
        let rhs: AttributesCalc = rhs.into();
        self.strength += rhs.strength;
        self.vitality += rhs.vitality;
        self.dexterity += rhs.dexterity;
        self.luck += rhs.luck;
        self
            .bludgeon_resistance =
                increase_resistance_calc(self.bludgeon_resistance, rhs.bludgeon_resistance);
        self
            .magic_resistance =
                increase_resistance_calc(self.magic_resistance, rhs.magic_resistance);
        self
            .pierce_resistance =
                increase_resistance_calc(self.pierce_resistance, rhs.pierce_resistance);
        self.bludgeon_vulnerability += rhs.bludgeon_vulnerability;
        self.magic_vulnerability += rhs.magic_vulnerability;
        self.pierce_vulnerability += rhs.pierce_vulnerability;
    }
}

#[generate_trait]
pub impl AttributesCalcImpl of AttributesCalcTrait {
    fn finalize(self: AttributesCalc) -> Attributes {
        Attributes {
            strength: self.strength.into_range(0, MAX_ABILITY_SCORE),
            vitality: self.vitality.into_range(0, MAX_ABILITY_SCORE),
            dexterity: self.dexterity.into_range(0, MAX_ABILITY_SCORE),
            luck: self.luck.into_range(0, MAX_ABILITY_SCORE),
            stun_resistance: self.stun_resistance.cap_into(100),
            bludgeon_resistance: self.bludgeon_resistance.cap_into(100),
            magic_resistance: self.magic_resistance.cap_into(100),
            pierce_resistance: self.pierce_resistance.cap_into(100),
            bludgeon_vulnerability: self.bludgeon_vulnerability.saturating_into(),
            magic_vulnerability: self.magic_vulnerability.saturating_into(),
            pierce_vulnerability: self.pierce_vulnerability.saturating_into(),
        }
    }

    fn mul(self: AttributesCalc, factor: u8) -> AttributesCalc {
        let factor_i32: i32 = factor.into();
        AttributesCalc {
            strength: self.strength * factor_i32,
            vitality: self.vitality * factor_i32,
            dexterity: self.dexterity * factor_i32,
            luck: self.luck * factor_i32,
            stun_resistance: mul_resistance(self.stun_resistance, factor),
            bludgeon_resistance: mul_resistance(self.bludgeon_resistance, factor),
            magic_resistance: mul_resistance(self.magic_resistance, factor),
            pierce_resistance: mul_resistance(self.pierce_resistance, factor),
            bludgeon_vulnerability: self.bludgeon_vulnerability * factor_i32,
            magic_vulnerability: self.magic_vulnerability * factor_i32,
            pierce_vulnerability: self.pierce_vulnerability * factor_i32,
        }
    }
}


#[generate_trait]
pub impl PartialAttributesImpl of PartialAttributesTrait {
    fn assert_valid(self: PartialAttributes) {
        assert(self.bludgeon_resistance <= 100, 'Invalid bludgeon resistance');
        assert(self.magic_resistance <= 100, 'Invalid magic resistance');
        assert(self.pierce_resistance <= 100, 'Invalid pierce resistance');
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
            stun_resistance: self.stun_resistance.into(),
            bludgeon_resistance: self.bludgeon_resistance.into(),
            magic_resistance: self.magic_resistance.into(),
            pierce_resistance: self.pierce_resistance.into(),
            bludgeon_vulnerability: self.bludgeon_vulnerability.into(),
            magic_vulnerability: self.magic_vulnerability.into(),
            pierce_vulnerability: self.pierce_vulnerability.into(),
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
            stun_resistance: self.stun_resistance.into(),
            bludgeon_resistance: self.bludgeon_resistance.into(),
            magic_resistance: self.magic_resistance.into(),
            pierce_resistance: self.pierce_resistance.into(),
            bludgeon_vulnerability: self.bludgeon_vulnerability.into(),
            magic_vulnerability: self.magic_vulnerability.into(),
            pierce_vulnerability: self.pierce_vulnerability.into(),
        }
    }
}


pub fn combine_partial_attributes(base: Attributes, items: Array<PartialAttributes>) -> Attributes {
    let mut calc = base.into();
    for item in items {
        calc += item;
    }
    calc.finalize()
}


fn combine_modifiers_u32(value: u32, change: u32) -> u32 {
    (value.wide_mul(change) / MODIFIER_SCALE_U32.into()).saturating_into()
}

fn combine_modifiers_u64(value: u64, change: u64) -> u64 {
    (value.wide_mul(change) / MODIFIER_SCALE_U64.into()).saturating_into()
}


impl PartialAttributesIntoAttributes of Into<PartialAttributes, Attributes> {
    fn into(self: PartialAttributes) -> Attributes {
        Attributes {
            strength: self.strength.saturating_into(),
            vitality: self.vitality.saturating_into(),
            dexterity: self.dexterity.saturating_into(),
            luck: self.luck.saturating_into(),
            stun_resistance: self.stun_resistance,
            bludgeon_resistance: self.bludgeon_resistance,
            magic_resistance: self.magic_resistance,
            pierce_resistance: self.pierce_resistance,
            bludgeon_vulnerability: self.bludgeon_vulnerability.saturating_into(),
            magic_vulnerability: self.magic_vulnerability.saturating_into(),
            pierce_vulnerability: self.pierce_vulnerability.saturating_into(),
        }
    }
}

impl AttributesStorePacking of StorePacking<Attributes, felt252> {
    fn pack(value: Attributes) -> felt252 {
        value.strength.into()
            + SHIFT_2B_FELT252 * value.vitality.into()
            + SHIFT_4B_FELT252 * value.dexterity.into()
            + SHIFT_6B_FELT252 * value.luck.into()
            + SHIFT_8B_FELT252 * value.stun_modifier.into()
            + SHIFT_95b_FELT252 * value.bludgeon_modifier.into()
            + SHIFT_126b_FELT252 * value.magic_modifier.into()
            + SHIFT_157b_FELT252 * value.pierce_modifier.into()
            + SHIFT_188b_FELT252 * value.damage_modifier.into()
    }

    fn unpack(value: felt252) -> Attributes {
        let value: u256 = value.into();
        let u256 { low, high } = value;
        Attributes {
            strength: MaskDowncast::cast(low),
            vitality: ShiftCast::const_unpack::<SHIFT_2B>(low),
            dexterity: ShiftCast::const_unpack::<SHIFT_4B>(low),
            luck: ShiftCast::const_unpack::<SHIFT_6B>(low),
            stun_modifier: ((low / SHIFT_8B) & MASK_31b_U128).try_into().unwrap(),
            bludgeon_modifier: ((low / SHIFT_95b) & MASK_31b_U128).try_into().unwrap(),
            magic_modifier: ((value / SHIFT_126b_U256) & MASK_31b_U256).try_into().unwrap(),
            pierce_modifier: ((high / SHIFT_29b_U128) & MASK_31b_U128).try_into().unwrap(),
            damage_modifier: ((high / SHIFT_60b_U128) & MASK_31b_U128).try_into().unwrap(),
        }
    }
}

fn pack_partial_attribute(value: i32) -> u32 {
    if value >= 0 {
        value.try_into().unwrap()
    } else {
        SHIFT_17b_U32 + (-value).try_into().unwrap()
    }
}

fn unpack_partial_attribute(value: u32) -> i32 {
    if value < SHIFT_17b_U32 {
        value.try_into().unwrap()
    } else {
        -(value - SHIFT_17b_U32).try_into().unwrap()
    }
}

impl PartialAttributesStorePacking of StorePacking<PartialAttributes, felt252> {
    fn pack(value: PartialAttributes) -> felt252 {
        pack_partial_attribute(value.strength).into()
            + SHIFT_17b_FELT252 * pack_partial_attribute(value.vitality).into()
            + SHIFT_34b_FELT252 * pack_partial_attribute(value.dexterity).into()
            + SHIFT_51b_FELT252 * pack_partial_attribute(value.luck).into()
            + SHIFT_68b_FELT252 * value.stun_modifier.into()
            + SHIFT_99b_FELT252 * value.bludgeon_modifier.into()
            + SHIFT_130b_FELT252 * value.magic_modifier.into()
            + SHIFT_161b_FELT252 * value.pierce_modifier.into()
            + SHIFT_192b_FELT252 * value.damage_modifier.into()
    }

    fn unpack(value: felt252) -> PartialAttributes {
        let value: u256 = value.into();
        let u256 { low, high } = value;
        PartialAttributes {
            strength: unpack_partial_attribute(MaskDowncast::cast(low)),
            vitality: unpack_partial_attribute(ShiftCast::const_unpack::<SHIFT_17b>(low)),
            dexterity: unpack_partial_attribute(ShiftCast::const_unpack::<SHIFT_34b>(low)),
            luck: unpack_partial_attribute(ShiftCast::const_unpack::<SHIFT_51b>(low)),
            stun_modifier: ((low / SHIFT_68b) & MASK_31b_U128).try_into().unwrap(),
            bludgeon_modifier: ((value / SHIFT_99b_U256) & MASK_31b_U256).try_into().unwrap(),
            magic_modifier: ((high / SHIFT_2b_U128) & MASK_31b_U128).try_into().unwrap(),
            pierce_modifier: ((high / SHIFT_33b_U128) & MASK_31b_U128).try_into().unwrap(),
            damage_modifier: ((high / SHIFT_64b_U128) & MASK_31b_U128).try_into().unwrap(),
        }
    }
}


impl AbilitiesIntoAttributes of Into<Abilities, Attributes> {
    fn into(self: Abilities) -> Attributes {
        Attributes {
            strength: self.strength,
            vitality: self.vitality,
            dexterity: self.dexterity,
            luck: self.luck,
            stun_resistance: 0,
            bludgeon_resistance: 0,
            magic_resistance: 0,
            pierce_resistance: 0,
            bludgeon_vulnerability: 0,
            magic_vulnerability: 0,
            pierce_vulnerability: 0,
        }
    }
}

impl AbilitiesStorePacking of StorePacking<Abilities, u32> {
    fn pack(value: Abilities) -> u32 {
        BytePacking::pack([value.strength, value.vitality, value.dexterity, value.luck])
    }

    fn unpack(value: u32) -> Abilities {
        let [strength, vitality, dexterity, luck] = BytePacking::unpack(value);
        Abilities { strength, vitality, dexterity, luck }
    }
}

impl AbilityModsStorePacking of StorePacking<AbilityMods, u32> {
    fn pack(value: AbilityMods) -> u32 {
        BytePacking::pack([value.strength, value.vitality, value.dexterity, value.luck])
    }

    fn unpack(value: u32) -> AbilityMods {
        let [strength, vitality, dexterity, luck] = BytePacking::unpack(value);
        AbilityMods { strength, vitality, dexterity, luck }
    }
}

impl ResistanceModsStorePacking of StorePacking<ResistanceMods, u32> {
    fn pack(value: ResistanceMods) -> u32 {
        BytePacking::pack([value.stun, value.bludgeon, value.magic, value.pierce])
    }

    fn unpack(value: u32) -> ResistanceMods {
        let [stun, bludgeon, magic, pierce] = BytePacking::unpack(value);
        ResistanceMods { stun, bludgeon, magic, pierce }
    }
}

impl VulnerabilityModsStorePacking of StorePacking<VulnerabilityMods, u64> {
    fn pack(value: VulnerabilityMods) -> u64 {
        IntPacking::pack_into(value.bludgeon)
            + ShiftCast::const_cast::<SHIFT_2B>(value.magic)
            + ShiftCast::const_cast::<SHIFT_4B>(value.pierce)
    }

    fn unpack(value: u64) -> VulnerabilityMods {
        let bludgeon: i16 = MaskDowncast::cast(value);
        let magic: i16 = ShiftCast::const_unpack::<SHIFT_2B>(value);
        let pierce: i16 = ShiftCast::const_unpack::<SHIFT_4B>(value);
        VulnerabilityMods { bludgeon, magic, pierce }
    }
}
