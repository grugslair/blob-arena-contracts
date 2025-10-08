use ba_utils::{CapInto, IntoRange};
use core::num::traits::Zero;
use core::ops::AddAssign;
use sai_core_utils::SaturatingInto;
use sai_packing::shifts::*;
use sai_packing::{BytePacking, IntPacking, MaskDowncast, ShiftCast};
use starknet::storage_access::StorePacking;

/// Maximum value for permanent ability scores
pub const MAX_ABILITY_SCORE: u8 = 100;
/// Maximum positive value for temporary ability score modifiers
pub const MAX_TEMP_ABILITY_SCORE: i8 = 100;
/// Maximum negative value for temporary ability score modifiers
pub const MIN_TEMP_ABILITY_SCORE: i8 = -100;

/// Represents the four core ability scores of a combatant
///
/// # Fields
/// * `strength` - Physical power, affects damage dealt (0-100)
/// * `vitality` - Health and endurance, affects maximum health (0-100)
/// * `dexterity` - Speed and agility, affects initiative and dodge (0-100)
/// * `luck` - Fortune and chance, affects critical hits and random events (0-100)
#[derive(Copy, Drop, Serde, Default, PartialEq, Introspect)]
pub struct Abilities {
    pub strength: u8,
    pub vitality: u8,
    pub dexterity: u8,
    pub luck: u8,
}

/// Represents modifiers to the four core ability scores
///
/// # Fields
/// * `strength` - Strength modifier (can be positive or negative)
/// * `vitality` - Vitality modifier (can be positive or negative)
/// * `dexterity` - Dexterity modifier (can be positive or negative)
/// * `luck` - Luck modifier (can be positive or negative)
#[derive(Copy, Drop, Serde, Default, PartialEq, Introspect)]
pub struct AbilityMods {
    pub strength: i8,
    pub vitality: i8,
    pub dexterity: i8,
    pub luck: i8,
}

/// Represents damage resistances and vulnerabilities (legacy struct)
///
/// # Fields
/// * `bludgeon_resistance` - Resistance to bludgeon damage (0-100%)
/// * `magic_resistance` - Resistance to magic damage (0-100%)
/// * `pierce_resistance` - Resistance to pierce damage (0-100%)
/// * `bludgeon_vulnerability` - Additional vulnerability to bludgeon damage
/// * `magic_vulnerability` - Additional vulnerability to magic damage
/// * `pierce_vulnerability` - Additional vulnerability to pierce damage
#[derive(Copy, Drop, Serde, Default, PartialEq, Introspect)]
pub struct Affinities {
    pub bludgeon_resistance: u8,
    pub magic_resistance: u8,
    pub pierce_resistance: u8,
    pub bludgeon_vulnerability: u16,
    pub magic_vulnerability: u16,
    pub pierce_vulnerability: u16,
}

/// Represents resistances to various damage types and effects
///
/// # Fields
/// * `stun` - Resistance to stun effects (0-100%)
/// * `bludgeon` - Resistance to bludgeon damage (0-100%)
/// * `magic` - Resistance to magic damage (0-100%)
/// * `pierce` - Resistance to pierce damage (0-100%)
#[derive(Copy, Drop, Serde, PartialEq, Default, Introspect)]
pub struct Resistances {
    pub stun: u8,
    pub bludgeon: u8,
    pub magic: u8,
    pub pierce: u8,
}

/// Represents vulnerabilities to various damage types
///
/// # Fields
/// * `bludgeon` - Additional vulnerability to bludgeon damage
/// * `magic` - Additional vulnerability to magic damage
/// * `pierce` - Additional vulnerability to pierce damage
#[derive(Copy, Drop, Serde, PartialEq, Default, Introspect)]
pub struct Vulnerabilities {
    pub bludgeon: u16,
    pub magic: u16,
    pub pierce: u16,
}


/// Represents modifiers to resistance values
///
/// # Fields
/// * `stun` - Stun resistance modifier (can be positive or negative)
/// * `bludgeon` - Bludgeon resistance modifier (can be positive or negative)
/// * `magic` - Magic resistance modifier (can be positive or negative)
/// * `pierce` - Pierce resistance modifier (can be positive or negative)
#[derive(Copy, Drop, Serde, PartialEq, Default, Introspect)]
pub struct ResistanceMods {
    pub stun: i8,
    pub bludgeon: i8,
    pub magic: i8,
    pub pierce: i8,
}

/// Represents modifiers to vulnerability values
///
/// # Fields
/// * `bludgeon` - Bludgeon vulnerability modifier (can be positive or negative)
/// * `magic` - Magic vulnerability modifier (can be positive or negative)
/// * `pierce` - Pierce vulnerability modifier (can be positive or negative)
#[derive(Copy, Drop, Serde, PartialEq, Default, Introspect)]
pub struct VulnerabilityMods {
    pub bludgeon: i16,
    pub magic: i16,
    pub pierce: i16,
}

/// Represents the complete set of attributes for a combatant
///
/// # Fields
/// ## Core Abilities
/// * `strength` - Physical power (0-100)
/// * `vitality` - Health and endurance (0-100)
/// * `dexterity` - Speed and agility (0-100)
/// * `luck` - Fortune and chance (0-100)
/// ## Resistances
/// * `stun_resistance` - Resistance to stun effects (0-100%)
/// * `bludgeon_resistance` - Resistance to bludgeon damage (0-100%)
/// * `magic_resistance` - Resistance to magic damage (0-100%)
/// * `pierce_resistance` - Resistance to pierce damage (0-100%)
/// ## Vulnerabilities
/// * `bludgeon_vulnerability` - Additional vulnerability to bludgeon damage
/// * `magic_vulnerability` - Additional vulnerability to magic damage
/// * `pierce_vulnerability` - Additional vulnerability to pierce damage
#[derive(Copy, Drop, Serde, PartialEq, Default, Introspect)]
pub struct Attributes {
    pub strength: u8,
    pub vitality: u8,
    pub dexterity: u8,
    pub luck: u8,
    pub stun_resistance: u8,
    pub bludgeon_resistance: u8,
    pub magic_resistance: u8,
    pub pierce_resistance: u8,
    pub bludgeon_vulnerability: u16,
    pub magic_vulnerability: u16,
    pub pierce_vulnerability: u16,
}

/// Represents partial attribute modifications that can be combined with base attributes
///
/// # Fields
/// ## Core Abilities (can be negative)
/// * `strength` - Strength modifier
/// * `vitality` - Vitality modifier
/// * `dexterity` - Dexterity modifier
/// * `luck` - Luck modifier
/// ## Resistances (additive)
/// * `stun_resistance` - Stun resistance bonus (0-100)
/// * `bludgeon_resistance` - Bludgeon resistance bonus (0-100)
/// * `magic_resistance` - Magic resistance bonus (0-100)
/// * `pierce_resistance` - Pierce resistance bonus (0-100)
/// ## Vulnerabilities (can be negative)
/// * `bludgeon_vulnerability` - Bludgeon vulnerability modifier
/// * `magic_vulnerability` - Magic vulnerability modifier
/// * `pierce_vulnerability` - Pierce vulnerability modifier
#[derive(Copy, Drop, Serde, Default, PartialEq, Introspect)]
pub struct PartialAttributes {
    pub strength: i8,
    pub vitality: i8,
    pub dexterity: i8,
    pub luck: i8,
    pub stun_resistance: u8,
    pub bludgeon_resistance: u8,
    pub magic_resistance: u8,
    pub pierce_resistance: u8,
    pub bludgeon_vulnerability: i16,
    pub magic_vulnerability: i16,
    pub pierce_vulnerability: i16,
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
/// * `stun_resistance` - Stun resistance during calculation (u16 for intermediate values)
/// * `bludgeon_resistance` - Bludgeon resistance during calculation (u16 for intermediate values)
/// * `magic_resistance` - Magic resistance during calculation (u16 for intermediate values)
/// * `pierce_resistance` - Pierce resistance during calculation (u16 for intermediate values)
/// * `bludgeon_vulnerability` - Bludgeon vulnerability during calculation (i32 for overflow safety)
/// * `magic_vulnerability` - Magic vulnerability during calculation (i32 for overflow safety)
/// * `pierce_vulnerability` - Pierce vulnerability during calculation (i32 for overflow safety)
#[derive(Copy, Drop, Default)]
pub struct AttributesCalc {
    pub strength: i32,
    pub vitality: i32,
    pub dexterity: i32,
    pub luck: i32,
    pub stun_resistance: u16,
    pub bludgeon_resistance: u16,
    pub magic_resistance: u16,
    pub pierce_resistance: u16,
    pub bludgeon_vulnerability: i32,
    pub magic_vulnerability: i32,
    pub pierce_vulnerability: i32,
}

fn mul_resistance(value: u16, factor: u8) -> u16 {
    if value.is_zero() || factor.is_zero() {
        return 0;
    }
    let mul = 100_u16 - value.into();
    let mut result = mul;
    for _ in 1..factor {
        result *= mul;
        result /= 100;
    }
    100 - result
}


impl AddAttributesCalc of Add<AttributesCalc> {
    fn add(lhs: AttributesCalc, rhs: AttributesCalc) -> AttributesCalc {
        AttributesCalc {
            strength: lhs.strength + rhs.strength,
            vitality: lhs.vitality + rhs.vitality,
            dexterity: lhs.dexterity + rhs.dexterity,
            luck: lhs.luck + rhs.luck,
            stun_resistance: increase_resistance_calc(lhs.stun_resistance, rhs.stun_resistance),
            bludgeon_resistance: increase_resistance_calc(
                lhs.bludgeon_resistance, rhs.bludgeon_resistance,
            ),
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


fn increase_resistance_calc(value: u16, change: u16) -> u16 {
    if change.is_zero() {
        return value;
    }
    if change == 100 || value == 100 {
        return 100;
    }
    (((value + change) * 100 - value * change) / 100).try_into().unwrap()
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

impl AttributesStorePacking of StorePacking<Attributes, u128> {
    fn pack(value: Attributes) -> u128 {
        value.strength.into()
            + ShiftCast::const_cast::<SHIFT_1B>(value.vitality)
            + ShiftCast::const_cast::<SHIFT_2B>(value.dexterity)
            + ShiftCast::const_cast::<SHIFT_3B>(value.luck)
            + ShiftCast::const_cast::<SHIFT_4B>(value.stun_resistance)
            + ShiftCast::const_cast::<SHIFT_5B>(value.bludgeon_resistance)
            + ShiftCast::const_cast::<SHIFT_6B>(value.magic_resistance)
            + ShiftCast::const_cast::<SHIFT_7B>(value.pierce_resistance)
            + ShiftCast::const_cast::<SHIFT_8B>(value.bludgeon_vulnerability)
            + ShiftCast::const_cast::<SHIFT_10B>(value.magic_vulnerability)
            + ShiftCast::const_cast::<SHIFT_12B>(value.pierce_vulnerability)
    }

    fn unpack(value: u128) -> Attributes {
        Attributes {
            strength: MaskDowncast::cast(value),
            vitality: ShiftCast::const_unpack::<SHIFT_1B>(value),
            dexterity: ShiftCast::const_unpack::<SHIFT_2B>(value),
            luck: ShiftCast::const_unpack::<SHIFT_3B>(value),
            stun_resistance: ShiftCast::const_unpack::<SHIFT_4B>(value),
            bludgeon_resistance: ShiftCast::const_unpack::<SHIFT_5B>(value),
            magic_resistance: ShiftCast::const_unpack::<SHIFT_6B>(value),
            pierce_resistance: ShiftCast::const_unpack::<SHIFT_7B>(value),
            bludgeon_vulnerability: ShiftCast::const_unpack::<SHIFT_8B>(value),
            magic_vulnerability: ShiftCast::const_unpack::<SHIFT_10B>(value),
            pierce_vulnerability: ShiftCast::const_unpack::<SHIFT_12B>(value),
        }
    }
}

impl PartialAttributesStorePacking of StorePacking<PartialAttributes, u128> {
    fn pack(value: PartialAttributes) -> u128 {
        IntPacking::pack(value.strength).into()
            + ShiftCast::const_cast::<SHIFT_1B>(value.vitality)
            + ShiftCast::const_cast::<SHIFT_2B>(value.dexterity)
            + ShiftCast::const_cast::<SHIFT_3B>(value.luck)
            + ShiftCast::const_cast::<SHIFT_4B>(value.stun_resistance)
            + ShiftCast::const_cast::<SHIFT_5B>(value.bludgeon_resistance)
            + ShiftCast::const_cast::<SHIFT_6B>(value.magic_resistance)
            + ShiftCast::const_cast::<SHIFT_7B>(value.pierce_resistance)
            + ShiftCast::const_cast::<SHIFT_8B>(value.bludgeon_vulnerability)
            + ShiftCast::const_cast::<SHIFT_10B>(value.magic_vulnerability)
            + ShiftCast::const_cast::<SHIFT_12B>(value.pierce_vulnerability)
    }

    fn unpack(value: u128) -> PartialAttributes {
        PartialAttributes {
            strength: MaskDowncast::cast(value),
            vitality: ShiftCast::const_unpack::<SHIFT_1B>(value),
            dexterity: ShiftCast::const_unpack::<SHIFT_2B>(value),
            luck: ShiftCast::const_unpack::<SHIFT_3B>(value),
            stun_resistance: ShiftCast::const_unpack::<SHIFT_4B>(value),
            bludgeon_resistance: ShiftCast::const_unpack::<SHIFT_5B>(value),
            magic_resistance: ShiftCast::const_unpack::<SHIFT_6B>(value),
            pierce_resistance: ShiftCast::const_unpack::<SHIFT_7B>(value),
            bludgeon_vulnerability: ShiftCast::const_unpack::<SHIFT_8B>(value),
            magic_vulnerability: ShiftCast::const_unpack::<SHIFT_10B>(value),
            pierce_vulnerability: ShiftCast::const_unpack::<SHIFT_12B>(value),
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
