use core::cmp::min;
use core::fmt::{Debug, Display, Error, Formatter};
use core::num::traits::{SaturatingAdd, SaturatingSub, Zero};
use core::ops::AddAssign;
use sai_core_utils::SaturatingInto;
use crate::signed::Signed;

const MAX_ABILITY_SCORE: u32 = 100;
const BASE_HEALTH: u32 = 100;

#[derive(Copy, Drop, Serde, PartialEq, Introspect, Default)]
struct TAbilities<T> {
    strength: T,
    vitality: T,
    dexterity: T,
    luck: T,
}

#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
enum AbilityTypes {
    Strength,
    Vitality,
    Dexterity,
    Luck,
}

impl TAbilitiesZeroable<T, +Zero<T>, +Drop<T>> of Zero<TAbilities<T>> {
    fn zero() -> TAbilities<T> {
        TAbilities {
            strength: Zero::zero(),
            vitality: Zero::zero(),
            dexterity: Zero::zero(),
            luck: Zero::zero(),
        }
    }
    fn is_zero(self: @TAbilities<T>) -> bool {
        self.strength.is_zero()
            && self.vitality.is_zero()
            && self.dexterity.is_zero()
            && self.luck.is_zero()
    }
    fn is_non_zero(self: @TAbilities<T>) -> bool {
        !self.is_zero()
    }
}


type UAbilities = TAbilities<u32>;
type IAbilities = TAbilities<i32>;
type SignedAbilities = TAbilities<Signed<u32>>;

impl TIntoTAbilities<T, +Copy<T>> of Into<T, TAbilities<T>> {
    fn into(self: T) -> TAbilities<T> {
        TAbilities { strength: self, vitality: self, dexterity: self, luck: self }
    }
}

fn add_buff(stat: u32, buff: i32) -> u32 {
    min(stat.saturating_into().saturating_add(buff).saturating_into(), 100)
}

fn apply_buff(ref stat: u32, buff: i32) -> i32 {
    let prev_value: i32 = stat.into();
    stat = add_buff(stat, buff);
    (stat.into() - prev_value).saturating_into()
}

#[generate_trait]
impl AbilitiesImpl of AbilitiesTrait {
    fn limit(ref self: UAbilities) {
        self.strength = min(self.strength, MAX_STAT);
        self.vitality = min(self.vitality, MAX_STAT);
        self.dexterity = min(self.dexterity, MAX_STAT);
        self.luck = min(self.luck, MAX_STAT);
    }
    fn apply_buff(ref self: UAbilities, stat: AbilityTypes, amount: i32) -> i32 {
        match stat {
            AbilityTypes::Strength => { apply_buff(ref self.strength, amount) },
            AbilityTypes::Vitality => { apply_buff(ref self.vitality, amount) },
            AbilityTypes::Dexterity => { apply_buff(ref self.dexterity, amount) },
            AbilityTypes::Luck => { apply_buff(ref self.luck, amount) },
        }
    }
    fn apply_buffs(ref self: UAbilities, buffs: TAbilities<i32>) -> IAbilities {
        IAbilities {
            strength: apply_buff(ref self.strength, buffs.strength),
            vitality: apply_buff(ref self.vitality, buffs.vitality),
            dexterity: apply_buff(ref self.dexterity, buffs.dexterity),
            luck: apply_buff(ref self.luck, buffs.luck),
        }
    }
    fn get_max_health(self: @UAbilities) -> u32 {
        *self.vitality + BASE_HEALTH
    }
}

#[generate_trait]
impl IAbilitiesImpl of IAbilitiesTrait {
    fn add_stat(ref self: IAbilities, stat: AbilityTypes, amount: i32) {
        match stat {
            AbilityTypes::Strength => { self.strength += amount },
            AbilityTypes::Vitality => { self.vitality += amount },
            AbilityTypes::Dexterity => { self.dexterity += amount },
            AbilityTypes::Luck => { self.luck += amount },
        }
    }
}


#[generate_trait]
impl TAbilitiesImpl<T, +Drop<T>, +Copy<T>> of TAbilitiesTrait<T> {
    fn get_stat(self: @TAbilities<T>, stat: AbilityTypes) -> T {
        match stat {
            AbilityTypes::Strength => *self.strength,
            AbilityTypes::Vitality => *self.vitality,
            AbilityTypes::Dexterity => *self.dexterity,
            AbilityTypes::Luck => *self.luck,
        }
    }

    fn set_stat(ref self: TAbilities<T>, stat: AbilityTypes, value: T) {
        match stat {
            AbilityTypes::Strength => { self.strength = value },
            AbilityTypes::Vitality => { self.vitality = value },
            AbilityTypes::Dexterity => { self.dexterity = value },
            AbilityTypes::Luck => { self.luck = value },
        }
    }
}

impl TAbilitiesAdd<T, +Add<T>, +Drop<T>> of Add<TAbilities<T>> {
    fn add(lhs: TAbilities<T>, rhs: TAbilities<T>) -> TAbilities<T> {
        TAbilities {
            strength: lhs.strength + rhs.strength,
            vitality: lhs.vitality + rhs.vitality,
            dexterity: lhs.dexterity + rhs.dexterity,
            luck: lhs.luck + rhs.luck,
        }
    }
}

impl TAbilitiesAddEq<T, +AddAssign<T, T>, +Drop<T>> of AddAssign<TAbilities<T>, TAbilities<T>> {
    fn add_assign(ref self: TAbilities<T>, rhs: TAbilities<T>) {
        self.strength += rhs.strength;
        self.vitality += rhs.vitality;
        self.dexterity += rhs.dexterity;
        self.luck += rhs.luck;
    }
}


impl TAbilitiesSaturatingSub<T, +SaturatingSub<T>, +Drop<T>> of SaturatingSub<TAbilities<T>> {
    fn saturating_sub(self: TAbilities<T>, other: TAbilities<T>) -> TAbilities<T> {
        TAbilities {
            strength: self.strength.saturating_sub(other.strength),
            vitality: self.vitality.saturating_sub(other.vitality),
            dexterity: self.dexterity.saturating_sub(other.dexterity),
            luck: self.luck.saturating_sub(other.luck),
        }
    }
}

impl TSaturatingAdd<T, +SaturatingAdd<T>, +Drop<T>> of SaturatingAdd<TAbilities<T>> {
    fn saturating_add(self: TAbilities<T>, other: TAbilities<T>) -> TAbilities<T> {
        TAbilities {
            strength: self.strength.saturating_add(other.strength),
            vitality: self.vitality.saturating_add(other.vitality),
            dexterity: self.dexterity.saturating_add(other.dexterity),
            luck: self.luck.saturating_add(other.luck),
        }
    }
}


impl TAbilitiesSub<T, +Sub<T>, +Drop<T>> of Sub<TAbilities<T>> {
    fn sub(lhs: TAbilities<T>, rhs: TAbilities<T>) -> TAbilities<T> {
        return TAbilities {
            strength: lhs.strength - rhs.strength,
            vitality: lhs.vitality - rhs.vitality,
            dexterity: lhs.dexterity - rhs.dexterity,
            luck: lhs.luck - rhs.luck,
        };
    }
}

impl TAbilitiesMul<T, +Mul<T>, +Drop<T>> of Mul<TAbilities<T>> {
    fn mul(lhs: TAbilities<T>, rhs: TAbilities<T>) -> TAbilities<T> {
        return TAbilities {
            strength: lhs.strength * rhs.strength,
            vitality: lhs.vitality * rhs.vitality,
            dexterity: lhs.dexterity * rhs.dexterity,
            luck: lhs.luck * rhs.luck,
        };
    }
}

impl TAbilitiesDiv<T, +Div<T>, +Drop<T>> of Div<TAbilities<T>> {
    fn div(lhs: TAbilities<T>, rhs: TAbilities<T>) -> TAbilities<T> {
        return TAbilities {
            strength: lhs.strength / rhs.strength,
            vitality: lhs.vitality / rhs.vitality,
            dexterity: lhs.dexterity / rhs.dexterity,
            luck: lhs.luck / rhs.luck,
        };
    }
}

impl TAbilitiesIntoTAbilitya<
    T, S, +Into<T, S>, +Copy<T>, +Drop<S>, +Drop<T>,
> of Into<TAbilities<T>, TAbilities<S>> {
    fn into(self: TAbilities<T>) -> TAbilities<S> {
        TAbilities {
            strength: self.strength.into(),
            vitality: self.vitality.into(),
            dexterity: self.dexterity.into(),
            luck: self.luck.into(),
        }
    }
}

impl TAbilitiesSaturatingIntoTAbilities<
    T, S, +SaturatingInto<T, S>, +Drop<T>, +Copy<T>, +Drop<S>,
> of SaturatingInto<TAbilities<T>, TAbilities<S>> {
    fn saturating_into(self: TAbilities<T>) -> TAbilities<S> {
        TAbilities {
            strength: self.strength.saturating_into(),
            vitality: self.vitality.saturating_into(),
            dexterity: self.dexterity.saturating_into(),
            luck: self.luck.saturating_into(),
        }
    }
}


impl AbilitiesDisplayImpl<T, +Debug<T>, +Drop<T>, +Copy<T>> of Display<TAbilities<T>> {
    fn fmt(self: @TAbilities<T>, ref f: Formatter) -> Result<(), Error> {
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
impl AbilitiesDebugImpl<T, +Display<TAbilities<T>>> of Debug<TAbilities<T>> {
    fn fmt(self: @TAbilities<T>, ref f: Formatter) -> Result<(), Error> {
        Display::fmt(self, ref f)
    }
}

