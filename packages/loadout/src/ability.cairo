use ba_utils::{CapInto, IntoRange};
use core::cmp::min;
use core::num::traits::{SaturatingAdd, Zero};
use core::ops::AddAssign;
use sai_core_utils::SaturatingInto;
use sai_packing::shifts::*;
use sai_packing::{IntPacking, MaskDowncast, ShiftCast};
use starknet::storage_access::StorePacking;

const MAX_ABILITY_SCORE: u8 = 100;
const BASE_HEALTH: u8 = 100;

#[derive(Copy, Drop, Serde, Default, Introspect)]
pub struct Abilities {
    pub strength: u8,
    pub vitality: u8,
    pub dexterity: u8,
    pub luck: u8,
}

#[derive(Copy, Drop, Serde, Default, Introspect)]
pub struct AbilitiesMods {
    pub strength: i8,
    pub vitality: i8,
    pub dexterity: i8,
    pub luck: i8,
}

#[derive(Copy, Drop, Serde, Default, Introspect)]
pub struct Affinities {
    pub bludgeon_resistance: u8,
    pub magic_resistance: u8,
    pub pierce_resistance: u8,
    pub bludgeon_vulnerability: u16,
    pub magic_vulnerability: u16,
    pub pierce_vulnerability: u16,
}

#[derive(Copy, Drop, Serde, Default, Introspect)]
pub struct AffinitiesMods {
    pub bludgeon_resistance: i8,
    pub magic_resistance: i8,
    pub pierce_resistance: i8,
    pub bludgeon_vulnerability: i16,
    pub magic_vulnerability: i16,
    pub pierce_vulnerability: i16,
}

#[derive(Copy, Drop, Serde, PartialEq, Default, Introspect)]
pub struct Resistances {
    pub bludgeon: u8,
    pub magic: u8,
    pub pierce: u8,
}

#[derive(Copy, Drop)]
pub struct CalcResistances {
    pub bludgeon: u64,
    pub magic: u64,
    pub pierce: u64,
}

#[derive(Copy, Drop, Serde, PartialEq, Default, Introspect)]
pub struct ResistanceMods {
    pub bludgeon: i8,
    pub magic: i8,
    pub pierce: i8,
}

#[derive(Copy, Drop, Serde, PartialEq, Default, Introspect)]
pub struct Vulnerabilities {
    pub bludgeon: u16,
    pub magic: u16,
    pub pierce: u16,
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


#[derive(Copy, Drop, Default, Add, AddAssign)]
struct AbilitiesVulnerabilities {
    pub strength: i32,
    pub vitality: i32,
    pub dexterity: i32,
    pub luck: i32,
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


fn combine_item_attributes(base: Attributes, mut items: Array<ItemAttributes>) -> Attributes {
    let mut combined = base;
    let mut resistances: CalcResistances = Default::default();

    let (mut abs_vulns_total, resistances) = items.pop_front().unwrap().split_resistances();
    let mut res_div = 1_u64;
    for item in items {
        let (abs_vulns, res) = item.split_resistances();
        abs_vulns_total += abs_vulns;
        res_div *= 100;
    }
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

impl ItemAttributesAdd of Add<ItemAttributes> {
    fn add(lhs: ItemAttributes, rhs: ItemAttributes) -> ItemAttributes {
        ItemAttributes {
            strength: lhs.strength + rhs.strength,
            vitality: lhs.vitality + rhs.vitality,
            dexterity: lhs.dexterity + rhs.dexterity,
            luck: lhs.luck + rhs.luck,
            bludgeon_resistance: increase_resistance(
                lhs.bludgeon_resistance, rhs.bludgeon_resistance,
            ),
            magic_resistance: increase_resistance(lhs.magic_resistance, rhs.magic_resistance),
            pierce_resistance: increase_resistance(lhs.pierce_resistance, rhs.pierce_resistance),
            bludgeon_vulnerability: lhs.bludgeon_vulnerability + rhs.bludgeon_vulnerability,
            magic_vulnerability: lhs.magic_vulnerability + rhs.magic_vulnerability,
            pierce_vulnerability: lhs.pierce_vulnerability + rhs.pierce_vulnerability,
        }
    }
}

impl ItemAttributesIntoAttributes of Into<ItemAttributes, Attributes> {
    fn into(self: ItemAttributes) -> Attributes {
        Attributes {
            strength: self.strength,
            vitality: self.vitality,
            dexterity: self.dexterity,
            luck: self.luck,
            bludgeon_resistance: self.bludgeon_resistance,
            magic_resistance: self.magic_resistance,
            pierce_resistance: self.pierce_resistance,
            bludgeon_vulnerability: self.bludgeon_vulnerability,
            magic_vulnerability: self.magic_vulnerability,
            pierce_vulnerability: self.pierce_vulnerability,
        }
    }
}

// impl DAbilitiesAddAssign of AddAssign<DAbilities, DAbilities> {
//     fn add_assign(ref self: DAbilities, rhs: DAbilities) {
//         self = self + rhs
//     }
// }

// impl AbilitiesAddAssign of AddAssign<Abilities, Abilities> {
//     fn add_assign(ref self: Abilities, rhs: Abilities) {
//         self = self + rhs
//     }
// }

// impl UAbilityStorePacking of StorePacking<Abilities, u128> {
//     fn pack(value: Abilities) -> u128 {
//         value.strength.into()
//             + ShiftCast::cast::<SHIFT_1B>(value.vitality)
//             + ShiftCast::cast::<SHIFT_2B>(value.dexterity)
//             + ShiftCast::cast::<SHIFT_3B>(value.luck)
//             + ShiftCast::cast::<SHIFT_4B>(value.bludgeon_resistance)
//             + ShiftCast::cast::<SHIFT_5B>(value.magic_resistance)
//             + ShiftCast::cast::<SHIFT_6B>(value.pierce_resistance)
//             + ShiftCast::cast::<SHIFT_7B>(value.bludgeon_vulnerability)
//             + ShiftCast::cast::<SHIFT_9B>(value.magic_vulnerability)
//             + ShiftCast::cast::<SHIFT_11B>(value.pierce_vulnerability)
//     }

//     fn unpack(value: u128) -> Abilities {
//         Abilities {
//             strength: MaskDowncast::cast(value),
//             vitality: ShiftCast::unpack::<SHIFT_1B>(value),
//             dexterity: ShiftCast::unpack::<SHIFT_2B>(value),
//             luck: ShiftCast::unpack::<SHIFT_3B>(value),
//             bludgeon_resistance: ShiftCast::unpack::<SHIFT_4B>(value),
//             magic_resistance: ShiftCast::unpack::<SHIFT_5B>(value),
//             pierce_resistance: ShiftCast::unpack::<SHIFT_6B>(value),
//             bludgeon_vulnerability: ShiftCast::unpack::<SHIFT_7B>(value),
//             magic_vulnerability: ShiftCast::unpack::<SHIFT_9B>(value),
//             pierce_vulnerability: ShiftCast::unpack::<SHIFT_11B>(value),
//         }
//     }
// }

// impl IAbilityStorePacking of StorePacking<DAbilities, u128> {
//     fn pack(value: DAbilities) -> u128 {
//         IntPacking::pack(value.strength).into()
//             + ShiftCast::cast::<SHIFT_1B>(value.vitality)
//             + ShiftCast::cast::<SHIFT_2B>(value.dexterity)
//             + ShiftCast::cast::<SHIFT_3B>(value.luck)
//             + ShiftCast::cast::<SHIFT_4B>(value.bludgeon_resistance)
//             + ShiftCast::cast::<SHIFT_5B>(value.magic_resistance)
//             + ShiftCast::cast::<SHIFT_6B>(value.pierce_resistance)
//             + ShiftCast::cast::<SHIFT_7B>(value.bludgeon_vulnerability)
//             + ShiftCast::cast::<SHIFT_9B>(value.magic_vulnerability)
//             + ShiftCast::cast::<SHIFT_11B>(value.pierce_vulnerability)
//     }

//     fn unpack(value: u128) -> DAbilities {
//         DAbilities {
//             strength: MaskDowncast::cast(value),
//             vitality: ShiftCast::unpack::<SHIFT_1B>(value),
//             dexterity: ShiftCast::unpack::<SHIFT_2B>(value),
//             luck: ShiftCast::unpack::<SHIFT_3B>(value),
//             bludgeon_resistance: ShiftCast::unpack::<SHIFT_4B>(value),
//             magic_resistance: ShiftCast::unpack::<SHIFT_5B>(value),
//             pierce_resistance: ShiftCast::unpack::<SHIFT_6B>(value),
//             bludgeon_vulnerability: ShiftCast::unpack::<SHIFT_7B>(value),
//             magic_vulnerability: ShiftCast::unpack::<SHIFT_9B>(value),
//             pierce_vulnerability: ShiftCast::unpack::<SHIFT_11B>(value),
//         }
//     }
// }

#[derive(Copy, Drop, Serde, PartialEq, Default, Introspect, starknet::Store)]
pub enum AbilityTypes {
    #[default]
    Strength,
    Vitality,
    Dexterity,
    Luck,
}

// fn add_attribute_modifier(stat: u8, buff: i8) -> u8 {
//     min(stat.saturating_into().saturating_add(buff).saturating_into(), MAX_ABILITY_SCORE)
// }

// fn apply_buff(ref current: u8, buff: i8) -> i8 {
//     let prev_value: i8 = current.try_into().unwrap();
//     current = add_buff(current, buff);
//     (current.try_into().unwrap() - prev_value)
// }

#[generate_trait]
pub impl ItemAttributesImpl of ItemAttributesTrait {
    fn split_resistances(self: ItemAttributes) -> (AbilitiesVulnerabilities, Resistances) {
        (
            AbilitiesVulnerabilities {
                strength: self.strength.into(),
                vitality: self.vitality.into(),
                dexterity: self.dexterity.into(),
                luck: self.luck.into(),
                bludgeon_vulnerability: self.bludgeon_vulnerability.into(),
                magic_vulnerability: self.magic_vulnerability.into(),
                pierce_vulnerability: self.pierce_vulnerability.into(),
            },
            Resistances {
                bludgeon: self.bludgeon_resistance,
                magic: self.magic_resistance,
                pierce: self.pierce_resistance,
            },
        )
    }
}
// #[generate_trait]
// pub impl AbilitiesImpl of AbilitiesTrait {
//     fn limit(ref self: Abilities) {
//         self.strength = min(self.strength, MAX_ABILITY_SCORE);
//         self.vitality = min(self.vitality, MAX_ABILITY_SCORE);
//         self.dexterity = min(self.dexterity, MAX_ABILITY_SCORE);
//         self.luck = min(self.luck, MAX_ABILITY_SCORE);
//     }

//     fn apply_buff(ref self: Abilities, stat: AbilityTypes, amount: i16) -> i16 {
//         match stat {
//             AbilityTypes::Strength => { apply_buff(ref self.strength, amount) },
//             AbilityTypes::Vitality => { apply_buff(ref self.vitality, amount) },
//             AbilityTypes::Dexterity => { apply_buff(ref self.dexterity, amount) },
//             AbilityTypes::Luck => { apply_buff(ref self.luck, amount) },
//         }
//     }

//     fn modify_strength(ref self: Abilities, amount: i8) -> i8 {
//         apply_buff(ref self.strength, amount)
//     }

//     fn modify_vitality(ref self: Abilities, amount: i8) -> i8 {
//         apply_buff(ref self.vitality, amount)
//     }

//     fn modify_dexterity(ref self: Abilities, amount: i8) -> i8 {
//         apply_buff(ref self.dexterity, amount)
//     }

//     fn modify_luck(ref self: Abilities, amount: i8) -> i8 {
//         apply_buff(ref self.luck, amount)
//     }

//     fn modify_(ref self: Abilities, buffs: DAbilities) -> DAbilities {
//         DAbilities {
//             strength: apply_buff(ref self.strength, buffs.strength),
//             vitality: apply_buff(ref self.vitality, buffs.vitality),
//             dexterity: apply_buff(ref self.dexterity, buffs.dexterity),
//             luck: apply_buff(ref self.luck, buffs.luck),
//         }
//     }
//     fn max_health(self: @Abilities) -> u8 {
//         *self.vitality + BASE_HEALTH
//     }

//     fn max_health_permille(self: @Abilities, permille: u16) -> u16 {
//         self.max_health() * permille / 1000
//     }

//     fn add_d_abilities(self: @Abilities, buffs: DAbilities) -> Abilities {
//         Abilities {
//             strength: add_buff(*self.strength, buffs.strength),
//             vitality: add_buff(*self.vitality, buffs.vitality),
//             dexterity: add_buff(*self.dexterity, buffs.dexterity),
//             luck: add_buff(*self.luck, buffs.luck),
//         }
//     }

//     fn get_stat(self: @Abilities, stat: AbilityTypes) -> u16 {
//         match stat {
//             AbilityTypes::Strength => *self.strength,
//             AbilityTypes::Vitality => *self.vitality,
//             AbilityTypes::Dexterity => *self.dexterity,
//             AbilityTypes::Luck => *self.luck,
//         }
//     }
// }

// #[generate_trait]
// pub impl DAbilitiesImpl of DAbilitiesTrait {
//     fn add_ability(ref self: DAbilities, stat: AbilityTypes, amount: i16) {
//         match stat {
//             AbilityTypes::Strength => { self.strength += amount },
//             AbilityTypes::Vitality => { self.vitality += amount },
//             AbilityTypes::Dexterity => { self.dexterity += amount },
//             AbilityTypes::Luck => { self.luck += amount },
//         }
//     }
// }

// impl AbilitiesSaturatingIntoDAbilities of SaturatingInto<Abilities, DAbilities> {
//     fn saturating_into(self: Abilities) -> DAbilities {
//         DAbilities {
//             strength: self.strength.saturating_into(),
//             vitality: self.vitality.saturating_into(),
//             dexterity: self.dexterity.saturating_into(),
//             luck: self.luck.saturating_into(),
//         }
//     }
// }

// impl DAbilitiesSaturatingIntoAbilities of SaturatingInto<DAbilities, Abilities> {
//     fn saturating_into(self: DAbilities) -> Abilities {
//         Abilities {
//             strength: self.strength.saturating_into(),
//             vitality: self.vitality.saturating_into(),
//             dexterity: self.dexterity.saturating_into(),
//             luck: self.luck.saturating_into(),
//         }
//     }
// }


