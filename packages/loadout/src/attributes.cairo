use ba_utils::{CapInto, IntoRange};
use core::num::traits::Zero;
use sai_core_utils::SaturatingInto;
use sai_packing::shifts::*;
use sai_packing::{BytePacking, IntPacking, MaskDowncast, ShiftCast};
use starknet::storage_access::StorePacking;

pub const MAX_ABILITY_SCORE: u8 = 100;

#[derive(Copy, Drop, Serde, Default, Introspect)]
pub struct Abilities {
    pub strength: u8,
    pub vitality: u8,
    pub dexterity: u8,
    pub luck: u8,
}

#[derive(Copy, Drop, Serde, Default, PartialEq, Introspect)]
pub struct AbilityMods {
    pub strength: i8,
    pub vitality: i8,
    pub dexterity: i8,
    pub luck: i8,
}

#[derive(Copy, Drop, Serde, Default, PartialEq, Introspect)]
pub struct Affinities {
    pub bludgeon_resistance: u8,
    pub magic_resistance: u8,
    pub pierce_resistance: u8,
    pub bludgeon_vulnerability: u16,
    pub magic_vulnerability: u16,
    pub pierce_vulnerability: u16,
}

#[derive(Copy, Drop, Serde, PartialEq, Default, Introspect)]
pub struct ResistanceMods {
    pub bludgeon: i8,
    pub magic: i8,
    pub pierce: i8,
}

#[derive(Copy, Drop, Serde, PartialEq, Default, Introspect)]
pub struct VulnerabilityMods {
    pub bludgeon: i16,
    pub magic: i16,
    pub pierce: i16,
}

#[derive(Copy, Drop, Serde, PartialEq, Default, Introspect)]
pub struct Attributes {
    pub strength: u8,
    pub vitality: u8,
    pub dexterity: u8,
    pub luck: u8,
    pub bludgeon_resistance: u8,
    pub magic_resistance: u8,
    pub pierce_resistance: u8,
    pub bludgeon_vulnerability: u16,
    pub magic_vulnerability: u16,
    pub pierce_vulnerability: u16,
}


#[derive(Copy, Drop, Serde, Default, PartialEq, Introspect)]
pub struct ItemAttributes {
    pub strength: i8,
    pub vitality: i8,
    pub dexterity: i8,
    pub luck: i8,
    pub bludgeon_resistance: u8,
    pub magic_resistance: u8,
    pub pierce_resistance: u8,
    pub bludgeon_vulnerability: u16,
    pub magic_vulnerability: u16,
    pub pierce_vulnerability: u16,
}

#[derive(Copy, Drop, Default)]
pub struct AttributesCalc {
    pub strength: i32,
    pub vitality: i32,
    pub dexterity: i32,
    pub luck: i32,
    pub bludgeon_resistance: u16,
    pub magic_resistance: u16,
    pub pierce_resistance: u16,
    pub bludgeon_vulnerability: u32,
    pub magic_vulnerability: u32,
    pub pierce_vulnerability: u32,
}

#[generate_trait]
impl AttributesCalcImpl of AttributesCalcTrait {
    fn add_item(ref self: AttributesCalc, item: ItemAttributes) {
        self.strength += item.strength.into();
        self.vitality += item.vitality.into();
        self.dexterity += item.dexterity.into();
        self.luck += item.luck.into();
        self
            .bludgeon_resistance =
                increase_resistance(self.bludgeon_resistance, item.bludgeon_resistance);
        self.magic_resistance = increase_resistance(self.magic_resistance, item.magic_resistance);
        self
            .pierce_resistance =
                increase_resistance(self.pierce_resistance, item.pierce_resistance);
        self.bludgeon_vulnerability += item.bludgeon_vulnerability.into();
        self.magic_vulnerability += item.magic_vulnerability.into();
        self.pierce_vulnerability += item.pierce_vulnerability.into();
    }

    fn finalize(self: AttributesCalc) -> Attributes {
        Attributes {
            strength: self.strength.into_range(0, MAX_ABILITY_SCORE),
            vitality: self.vitality.into_range(0, MAX_ABILITY_SCORE),
            dexterity: self.dexterity.into_range(0, MAX_ABILITY_SCORE),
            luck: self.luck.into_range(0, MAX_ABILITY_SCORE),
            bludgeon_resistance: self.bludgeon_resistance.cap_into(100),
            magic_resistance: self.magic_resistance.cap_into(100),
            pierce_resistance: self.pierce_resistance.cap_into(100),
            bludgeon_vulnerability: self.bludgeon_vulnerability.cap_into(10000),
            magic_vulnerability: self.magic_vulnerability.cap_into(10000),
            pierce_vulnerability: self.pierce_vulnerability.cap_into(10000),
        }
    }
}

impl AttributesIntoAttributesCalc of Into<Attributes, AttributesCalc> {
    fn into(self: Attributes) -> AttributesCalc {
        AttributesCalc {
            strength: self.strength.into(),
            vitality: self.vitality.into(),
            dexterity: self.dexterity.into(),
            luck: self.luck.into(),
            bludgeon_resistance: self.bludgeon_resistance.into(),
            magic_resistance: self.magic_resistance.into(),
            pierce_resistance: self.pierce_resistance.into(),
            bludgeon_vulnerability: self.bludgeon_vulnerability.into(),
            magic_vulnerability: self.magic_vulnerability.into(),
            pierce_vulnerability: self.pierce_vulnerability.into(),
        }
    }
}


fn combine_item_attributes(base: Attributes, items: Array<ItemAttributes>) -> Attributes {
    let mut calc = base.into();
    for item in items {
        calc.add_item(item);
    }
    calc.finalize()
}


fn combine_resistance<T, +Drop<T>, +Into<T, i16>>(value: u8, change: T) -> u8 {
    let value: i16 = value.into();
    let change: i16 = change.into();
    if change == 100 {
        return 100;
    }
    let sum = value + change;
    if sum <= Zero::zero() {
        Zero::zero()
    } else if change < 0 {
        sum * 100 / (100 + change)
    } else {
        (sum * 100 - value * change) / 100
    }
        .try_into()
        .unwrap()
}

fn increase_resistance(value: u16, change: u8) -> u16 {
    if change.is_zero() {
        return value;
    }
    if change == 100 || value == 100 {
        return 100;
    }
    let change: u16 = change.into();
    (((value + change) * 100 - value * change) / 100).try_into().unwrap()
}

impl ItemAttributesIntoAttributes of Into<ItemAttributes, Attributes> {
    fn into(self: ItemAttributes) -> Attributes {
        Attributes {
            strength: self.strength.saturating_into(),
            vitality: self.vitality.saturating_into(),
            dexterity: self.dexterity.saturating_into(),
            luck: self.luck.saturating_into(),
            bludgeon_resistance: self.bludgeon_resistance,
            magic_resistance: self.magic_resistance,
            pierce_resistance: self.pierce_resistance,
            bludgeon_vulnerability: self.bludgeon_vulnerability,
            magic_vulnerability: self.magic_vulnerability,
            pierce_vulnerability: self.pierce_vulnerability,
        }
    }
}

impl AttributesStorePacking of StorePacking<Attributes, u128> {
    fn pack(value: Attributes) -> u128 {
        value.strength.into()
            + ShiftCast::cast::<SHIFT_1B>(value.vitality)
            + ShiftCast::cast::<SHIFT_2B>(value.dexterity)
            + ShiftCast::cast::<SHIFT_3B>(value.luck)
            + ShiftCast::cast::<SHIFT_4B>(value.bludgeon_resistance)
            + ShiftCast::cast::<SHIFT_5B>(value.magic_resistance)
            + ShiftCast::cast::<SHIFT_6B>(value.pierce_resistance)
            + ShiftCast::cast::<SHIFT_7B>(value.bludgeon_vulnerability)
            + ShiftCast::cast::<SHIFT_9B>(value.magic_vulnerability)
            + ShiftCast::cast::<SHIFT_11B>(value.pierce_vulnerability)
    }

    fn unpack(value: u128) -> Attributes {
        Attributes {
            strength: MaskDowncast::cast(value),
            vitality: ShiftCast::unpack::<SHIFT_1B>(value),
            dexterity: ShiftCast::unpack::<SHIFT_2B>(value),
            luck: ShiftCast::unpack::<SHIFT_3B>(value),
            bludgeon_resistance: ShiftCast::unpack::<SHIFT_4B>(value),
            magic_resistance: ShiftCast::unpack::<SHIFT_5B>(value),
            pierce_resistance: ShiftCast::unpack::<SHIFT_6B>(value),
            bludgeon_vulnerability: ShiftCast::unpack::<SHIFT_7B>(value),
            magic_vulnerability: ShiftCast::unpack::<SHIFT_9B>(value),
            pierce_vulnerability: ShiftCast::unpack::<SHIFT_11B>(value),
        }
    }
}

impl ItemAttributesStorePacking of StorePacking<ItemAttributes, u128> {
    fn pack(value: ItemAttributes) -> u128 {
        IntPacking::pack(value.strength).into()
            + ShiftCast::cast::<SHIFT_1B>(value.vitality)
            + ShiftCast::cast::<SHIFT_2B>(value.dexterity)
            + ShiftCast::cast::<SHIFT_3B>(value.luck)
            + ShiftCast::cast::<SHIFT_4B>(value.bludgeon_resistance)
            + ShiftCast::cast::<SHIFT_5B>(value.magic_resistance)
            + ShiftCast::cast::<SHIFT_6B>(value.pierce_resistance)
            + ShiftCast::cast::<SHIFT_7B>(value.bludgeon_vulnerability)
            + ShiftCast::cast::<SHIFT_9B>(value.magic_vulnerability)
            + ShiftCast::cast::<SHIFT_11B>(value.pierce_vulnerability)
    }

    fn unpack(value: u128) -> ItemAttributes {
        ItemAttributes {
            strength: MaskDowncast::cast(value),
            vitality: ShiftCast::unpack::<SHIFT_1B>(value),
            dexterity: ShiftCast::unpack::<SHIFT_2B>(value),
            luck: ShiftCast::unpack::<SHIFT_3B>(value),
            bludgeon_resistance: ShiftCast::unpack::<SHIFT_4B>(value),
            magic_resistance: ShiftCast::unpack::<SHIFT_5B>(value),
            pierce_resistance: ShiftCast::unpack::<SHIFT_6B>(value),
            bludgeon_vulnerability: ShiftCast::unpack::<SHIFT_7B>(value),
            magic_vulnerability: ShiftCast::unpack::<SHIFT_9B>(value),
            pierce_vulnerability: ShiftCast::unpack::<SHIFT_11B>(value),
        }
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
        IntPacking::pack_into(value.bludgeon)
            + ShiftCast::cast::<SHIFT_1B>(value.magic)
            + ShiftCast::cast::<SHIFT_2B>(value.pierce)
    }

    fn unpack(value: u32) -> ResistanceMods {
        let bludgeon: i8 = MaskDowncast::cast(value);
        let magic: i8 = ShiftCast::unpack::<SHIFT_1B>(value);
        let pierce: i8 = ShiftCast::unpack::<SHIFT_2B>(value);
        ResistanceMods { bludgeon, magic, pierce }
    }
}
