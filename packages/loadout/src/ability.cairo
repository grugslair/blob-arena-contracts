use core::cmp::min;
use core::fmt::{Debug, Display, Error, Formatter};
use core::num::traits::{Pow, SaturatingAdd, Zero};
use sai_core_utils::SaturatingInto;
use sai_packing::IntPacking;
use starknet::storage_access::StorePacking;
// use crate::signed::Signed;

const MAX_ABILITY_SCORE: u32 = 100;
const BASE_HEALTH: u32 = 100;

#[beacon_entity]
#[derive(
    Copy,
    Drop,
    Serde,
    Default,
    PartialEq,
    Introspect,
    Add,
    Sub,
    Mul,
    Div,
    AddAssign,
    SubAssign,
    MulAssign,
    DivAssign,
)]
pub struct Abilities {
    pub strength: u32,
    pub vitality: u32,
    pub dexterity: u32,
    pub luck: u32,
}

#[derive(
    Copy,
    Drop,
    Serde,
    Default,
    PartialEq,
    Introspect,
    Add,
    Sub,
    Mul,
    Div,
    AddAssign,
    SubAssign,
    MulAssign,
    DivAssign,
)]
pub struct DAbilities {
    pub strength: i32,
    pub vitality: i32,
    pub dexterity: i32,
    pub luck: i32,
}

const U32_SHIFT_1: u128 = 2_u128.pow(32);
const U32_SHIFT_2: u128 = 2_u128.pow(64);
const U32_SHIFT_3: u128 = 2_u128.pow(96);

const U32_MASK_U128: u128 = U32_SHIFT_1 - 1;


impl UAbilityStorePacking of StorePacking<Abilities, u128> {
    fn pack(value: Abilities) -> u128 {
        (value.strength.into()
            + value.vitality.into() * U32_SHIFT_1
            + value.dexterity.into() * U32_SHIFT_2
            + value.luck.into() * U32_SHIFT_3)
            .into()
    }

    fn unpack(value: u128) -> Abilities {
        let strength = (value & U32_MASK_U128).try_into().unwrap();
        let vitality = ((value / U32_SHIFT_1) & U32_MASK_U128).try_into().unwrap();
        let dexterity = ((value / U32_SHIFT_2) & U32_MASK_U128).try_into().unwrap();
        let luck = ((value / U32_SHIFT_3) & U32_MASK_U128).try_into().unwrap();
        Abilities { strength, vitality, dexterity, luck }
    }
}

impl IAbilityStorePacking of StorePacking<DAbilities, u128> {
    fn pack(value: DAbilities) -> u128 {
        value.strength.pack().into()
            + value.vitality.pack().into() * U32_SHIFT_1
            + value.dexterity.pack().into() * U32_SHIFT_2
            + value.luck.pack().into() * U32_SHIFT_3.into()
    }

    fn unpack(value: u128) -> DAbilities {
        let strength: i32 = IntPacking::unpack((value & U32_MASK_U128).try_into().unwrap());
        let vitality: i32 = IntPacking::unpack(
            ((value / U32_SHIFT_1) & U32_MASK_U128).try_into().unwrap(),
        );
        let dexterity: i32 = IntPacking::unpack(
            ((value / U32_SHIFT_2) & U32_MASK_U128).try_into().unwrap(),
        );
        let luck: i32 = IntPacking::unpack(
            ((value / U32_SHIFT_3) & U32_MASK_U128).try_into().unwrap(),
        );
        DAbilities { strength, vitality, dexterity, luck }
    }
}

#[derive(Copy, Drop, Serde, PartialEq, Default, Introspect, starknet::Store)]
pub enum AbilityTypes {
    #[default]
    Strength,
    Vitality,
    Dexterity,
    Luck,
}


impl U32IntoAbilities of Into<u32, Abilities> {
    fn into(self: u32) -> Abilities {
        Abilities { strength: self, vitality: self, dexterity: self, luck: self }
    }
}

impl I32IntoDAbilities of Into<i32, DAbilities> {
    fn into(self: i32) -> DAbilities {
        DAbilities { strength: self, vitality: self, dexterity: self, luck: self }
    }
}

impl DAbilitiesZeroable of Zero<DAbilities> {
    fn zero() -> DAbilities {
        0_i32.into()
    }
    fn is_zero(self: @DAbilities) -> bool {
        self.strength.is_zero()
            && self.vitality.is_zero()
            && self.dexterity.is_zero()
            && self.luck.is_zero()
    }
    fn is_non_zero(self: @DAbilities) -> bool {
        !self.is_zero()
    }
}

impl AbilitiesZeroable of Zero<Abilities> {
    fn zero() -> Abilities {
        0_u32.into()
    }
    fn is_zero(self: @Abilities) -> bool {
        self.strength.is_zero()
            && self.vitality.is_zero()
            && self.dexterity.is_zero()
            && self.luck.is_zero()
    }
    fn is_non_zero(self: @Abilities) -> bool {
        !self.is_zero()
    }
}


// pub type Abilities = TAbilities<u32>;

// pub type DAbilities = TAbilities<i32>;
// pub type SignedAbilities = TAbilities<Signed<u32>>;

fn add_buff(stat: u32, buff: i32) -> u32 {
    min(stat.saturating_into().saturating_add(buff).saturating_into(), MAX_ABILITY_SCORE)
}

fn apply_buff(ref current: u32, buff: i32) -> i32 {
    let prev_value: i32 = current.try_into().unwrap();
    current = add_buff(current, buff);
    (current.try_into().unwrap() - prev_value)
}

#[generate_trait]
impl AbilitiesImpl of AbilitiesTrait {
    fn limit(ref self: Abilities) {
        self.strength = min(self.strength, MAX_ABILITY_SCORE);
        self.vitality = min(self.vitality, MAX_ABILITY_SCORE);
        self.dexterity = min(self.dexterity, MAX_ABILITY_SCORE);
        self.luck = min(self.luck, MAX_ABILITY_SCORE);
    }
    fn apply_buff(ref self: Abilities, stat: AbilityTypes, amount: i32) -> i32 {
        match stat {
            AbilityTypes::Strength => { apply_buff(ref self.strength, amount) },
            AbilityTypes::Vitality => { apply_buff(ref self.vitality, amount) },
            AbilityTypes::Dexterity => { apply_buff(ref self.dexterity, amount) },
            AbilityTypes::Luck => { apply_buff(ref self.luck, amount) },
        }
    }
    fn apply_buffs(ref self: Abilities, buffs: DAbilities) -> DAbilities {
        DAbilities {
            strength: apply_buff(ref self.strength, buffs.strength),
            vitality: apply_buff(ref self.vitality, buffs.vitality),
            dexterity: apply_buff(ref self.dexterity, buffs.dexterity),
            luck: apply_buff(ref self.luck, buffs.luck),
        }
    }
    fn get_max_health(self: @Abilities) -> u32 {
        *self.vitality + BASE_HEALTH
    }
    fn get_stat(self: @Abilities, stat: AbilityTypes) -> u32 {
        match stat {
            AbilityTypes::Strength => *self.strength,
            AbilityTypes::Vitality => *self.vitality,
            AbilityTypes::Dexterity => *self.dexterity,
            AbilityTypes::Luck => *self.luck,
        }
    }
}

#[generate_trait]
impl DAbilitiesImpl of DAbilitiesTrait {
    fn add_stat(ref self: DAbilities, stat: AbilityTypes, amount: i32) {
        match stat {
            AbilityTypes::Strength => { self.strength += amount },
            AbilityTypes::Vitality => { self.vitality += amount },
            AbilityTypes::Dexterity => { self.dexterity += amount },
            AbilityTypes::Luck => { self.luck += amount },
        }
    }
}

impl AbilitiesSaturatingIntoDAbilities of SaturatingInto<Abilities, DAbilities> {
    fn saturating_into(self: Abilities) -> DAbilities {
        DAbilities {
            strength: self.strength.saturating_into(),
            vitality: self.vitality.saturating_into(),
            dexterity: self.dexterity.saturating_into(),
            luck: self.luck.saturating_into(),
        }
    }
}

impl DAbilitiesSaturatingIntoAbilities of SaturatingInto<DAbilities, Abilities> {
    fn saturating_into(self: DAbilities) -> Abilities {
        Abilities {
            strength: self.strength.saturating_into(),
            vitality: self.vitality.saturating_into(),
            dexterity: self.dexterity.saturating_into(),
            luck: self.luck.saturating_into(),
        }
    }
}

impl AbilitiesDisplayImpl of Display<Abilities> {
    fn fmt(self: @Abilities, ref f: Formatter) -> Result<(), Error> {
        write!(
            f,
            "strength: {:?}, vitality: {:?}, dexterity: {:?}, luck: {:?}",
            *self.strength,
            *self.vitality,
            *self.dexterity,
            *self.luck,
        )
    }
}
impl AbilitiesDebugImpl of Debug<Abilities> {
    fn fmt(self: @Abilities, ref f: Formatter) -> Result<(), Error> {
        Display::fmt(self, ref f)
    }
}

