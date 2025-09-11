use core::cmp::min;
use core::fmt::{Debug, Display, Error, Formatter};
use core::num::traits::{SaturatingAdd, Zero};
use core::ops::AddAssign;
use sai_core_utils::SaturatingInto;
use sai_packing::byte::SHIFT_2B_U32;
use sai_packing::{BytePacking, IntPacking, MaskDowncast, SHIFT_2B, ShiftCast};
use starknet::storage_access::StorePacking;
// use crate::signed::Signed;

const MAX_ABILITY_SCORE: u16 = 100;
const BASE_HEALTH: u16 = 100;
const STRENGTH_PACKING_BIT: u32 = SHIFT_2B_U32;
const VITALITY_PACKING_BIT: u32 = SHIFT_2B_U32 * 2;
const DEXTERITY_PACKING_BIT: u32 = SHIFT_2B_U32 * 3;
const LUCK_PACKING_BIT: u32 = SHIFT_2B_U32 * 4;

#[derive(Copy, Drop, Serde, Default, PartialEq, Introspect)]
pub struct Abilities {
    pub strength: u16,
    pub vitality: u16,
    pub dexterity: u16,
    pub luck: u16,
}

#[derive(Copy, Drop, Serde, Default, PartialEq, Introspect)]
pub struct DAbilities {
    pub strength: i16,
    pub vitality: i16,
    pub dexterity: i16,
    pub luck: i16,
}


impl DAbilitiesAdd of Add<DAbilities> {
    fn add(lhs: DAbilities, rhs: DAbilities) -> DAbilities {
        DAbilities {
            strength: lhs.strength + rhs.strength,
            vitality: lhs.vitality + rhs.vitality,
            dexterity: lhs.dexterity + rhs.dexterity,
            luck: lhs.luck + rhs.luck,
        }
    }
}

impl AbilitiesAdd of Add<Abilities> {
    fn add(lhs: Abilities, rhs: Abilities) -> Abilities {
        Abilities {
            strength: lhs.strength + rhs.strength,
            vitality: lhs.vitality + rhs.vitality,
            dexterity: lhs.dexterity + rhs.dexterity,
            luck: lhs.luck + rhs.luck,
        }
    }
}

impl DAbilitiesAddAssign of AddAssign<DAbilities, DAbilities> {
    fn add_assign(ref self: DAbilities, rhs: DAbilities) {
        self = self + rhs
    }
}

impl AbilitiesAddAssign of AddAssign<Abilities, Abilities> {
    fn add_assign(ref self: Abilities, rhs: Abilities) {
        self = self + rhs
    }
}

impl UAbilityStorePacking of StorePacking<Abilities, u64> {
    fn pack(value: Abilities) -> u64 {
        BytePacking::pack([value.strength, value.vitality, value.dexterity, value.luck])
    }

    fn unpack(value: u64) -> Abilities {
        let [strength, vitality, dexterity, luck] = BytePacking::unpack(value);
        Abilities { strength, vitality, dexterity, luck }
    }
}

impl IAbilityStorePacking of StorePacking<DAbilities, u64> {
    fn pack(value: DAbilities) -> u64 {
        BytePacking::pack([value.strength, value.vitality, value.dexterity, value.luck])
    }

    fn unpack(value: u64) -> DAbilities {
        let [strength, vitality, dexterity, luck] = BytePacking::unpack(value);
        DAbilities { strength, vitality, dexterity, luck }
    }
}

#[derive(Copy, Drop, Serde, PartialEq, Default, Introspect)]
pub enum AbilityEffect {
    #[default]
    None,
    Strength: i16,
    Vitality: i16,
    Dexterity: i16,
    Luck: i16,
}

impl AbilityEffectStorePacking of StorePacking<AbilityEffect, u32> {
    fn pack(value: AbilityEffect) -> u32 {
        let (amount, variant) = match value {
            AbilityEffect::None => { return 0; },
            AbilityEffect::Strength(amount) => (amount, STRENGTH_PACKING_BIT),
            AbilityEffect::Vitality(amount) => (amount, VITALITY_PACKING_BIT),
            AbilityEffect::Dexterity(amount) => (amount, DEXTERITY_PACKING_BIT),
            AbilityEffect::Luck(amount) => (amount, LUCK_PACKING_BIT),
        };
        IntPacking::pack(amount).into() + variant
    }

    fn unpack(value: u32) -> AbilityEffect {
        if value < STRENGTH_PACKING_BIT {
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
            _ => panic!("Invalid value for AbilityEffect"),
        }
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


impl U32IntoAbilities of Into<u16, Abilities> {
    fn into(self: u16) -> Abilities {
        Abilities { strength: self, vitality: self, dexterity: self, luck: self }
    }
}

impl I32IntoDAbilities of Into<i16, DAbilities> {
    fn into(self: i16) -> DAbilities {
        DAbilities { strength: self, vitality: self, dexterity: self, luck: self }
    }
}

impl DAbilitiesZeroable of Zero<DAbilities> {
    fn zero() -> DAbilities {
        0_i16.into()
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
        0_u16.into()
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


// pub type Abilities = TAbilities<u16>;

// pub type DAbilities = TAbilities<i16>;
// pub type SignedAbilities = TAbilities<Signed<u16>>;

fn add_buff(stat: u16, buff: i16) -> u16 {
    min(stat.saturating_into().saturating_add(buff).saturating_into(), MAX_ABILITY_SCORE)
}

fn apply_buff(ref current: u16, buff: i16) -> i16 {
    let prev_value: i16 = current.try_into().unwrap();
    current = add_buff(current, buff);
    (current.try_into().unwrap() - prev_value)
}

#[generate_trait]
pub impl AbilitiesImpl of AbilitiesTrait {
    fn limit(ref self: Abilities) {
        self.strength = min(self.strength, MAX_ABILITY_SCORE);
        self.vitality = min(self.vitality, MAX_ABILITY_SCORE);
        self.dexterity = min(self.dexterity, MAX_ABILITY_SCORE);
        self.luck = min(self.luck, MAX_ABILITY_SCORE);
    }
    fn apply_buff(ref self: Abilities, stat: AbilityTypes, amount: i16) -> i16 {
        match stat {
            AbilityTypes::Strength => { apply_buff(ref self.strength, amount) },
            AbilityTypes::Vitality => { apply_buff(ref self.vitality, amount) },
            AbilityTypes::Dexterity => { apply_buff(ref self.dexterity, amount) },
            AbilityTypes::Luck => { apply_buff(ref self.luck, amount) },
        }
    }

    fn apply_strength_buff(ref self: Abilities, amount: i16) -> i16 {
        apply_buff(ref self.strength, amount)
    }

    fn apply_vitality_buff(ref self: Abilities, amount: i16) -> i16 {
        apply_buff(ref self.vitality, amount)
    }

    fn apply_dexterity_buff(ref self: Abilities, amount: i16) -> i16 {
        apply_buff(ref self.dexterity, amount)
    }

    fn apply_luck_buff(ref self: Abilities, amount: i16) -> i16 {
        apply_buff(ref self.luck, amount)
    }

    fn apply_buffs(ref self: Abilities, buffs: DAbilities) -> DAbilities {
        DAbilities {
            strength: apply_buff(ref self.strength, buffs.strength),
            vitality: apply_buff(ref self.vitality, buffs.vitality),
            dexterity: apply_buff(ref self.dexterity, buffs.dexterity),
            luck: apply_buff(ref self.luck, buffs.luck),
        }
    }
    fn max_health(self: @Abilities) -> u16 {
        *self.vitality + BASE_HEALTH
    }

    fn max_health_permille(self: @Abilities, permille: u16) -> u16 {
        self.max_health() * permille / 1000
    }


    fn get_stat(self: @Abilities, stat: AbilityTypes) -> u16 {
        match stat {
            AbilityTypes::Strength => *self.strength,
            AbilityTypes::Vitality => *self.vitality,
            AbilityTypes::Dexterity => *self.dexterity,
            AbilityTypes::Luck => *self.luck,
        }
    }
}

#[generate_trait]
pub impl DAbilitiesImpl of DAbilitiesTrait {
    fn add_ability(ref self: DAbilities, stat: AbilityTypes, amount: i16) {
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

