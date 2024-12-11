use core::{fmt::{Display, Formatter, Error, Debug}, cmp::min, ops::AddAssign};
use blob_arena::{
    core::{SaturatingAdd, SaturatingSub, SaturatingInto, Signed, SumTArray},
    constants::{STARTING_HEALTH, MAX_STAT}
};


#[derive(Copy, Drop, Serde, PartialEq, IntrospectPacked, Default)]
struct TStats<T> {
    strength: T,
    vitality: T,
    dexterity: T,
    luck: T,
}

#[derive(Copy, Drop, Serde, PartialEq, IntrospectPacked)]
enum StatTypes {
    Strength,
    Vitality,
    Dexterity,
    Luck,
}

impl TStatsZeroable<T, +Zeroable<T>, +Drop<T>> of Zeroable<TStats<T>> {
    fn zero() -> TStats<T> {
        TStats {
            strength: Zeroable::zero(),
            vitality: Zeroable::zero(),
            dexterity: Zeroable::zero(),
            luck: Zeroable::zero()
        }
    }
    fn is_zero(self: TStats<T>) -> bool {
        self.strength.is_zero()
            && self.vitality.is_zero()
            && self.dexterity.is_zero()
            && self.luck.is_zero()
    }
    fn is_non_zero(self: TStats<T>) -> bool {
        !self.is_zero()
    }
}


type UStats = TStats<u8>;
type IStats = TStats<i8>;
type SignedStats = TStats<Signed<u8>>;

impl TIntoTStats<T, +Copy<T>> of Into<T, TStats<T>> {
    fn into(self: T) -> TStats<T> {
        TStats { strength: self, vitality: self, dexterity: self, luck: self, }
    }
}

fn add_buff(stat: u8, buff: i8) -> u8 {
    min(stat.saturating_into().saturating_add(buff).saturating_into(), 100)
}

#[generate_trait]
impl StatsImpl of StatsTrait {
    fn limit_stats(ref self: UStats) {
        self.strength = min(self.strength, MAX_STAT);
        self.vitality = min(self.vitality, MAX_STAT);
        self.dexterity = min(self.dexterity, MAX_STAT);
        self.luck = min(self.luck, MAX_STAT);
    }
    fn apply_buff(ref self: UStats, stat: StatTypes, amount: i8) {
        match stat {
            StatTypes::Strength => { self.strength = add_buff(self.strength, amount) },
            StatTypes::Vitality => { self.vitality = add_buff(self.vitality, amount) },
            StatTypes::Dexterity => { self.dexterity = add_buff(self.dexterity, amount) },
            StatTypes::Luck => { self.luck = add_buff(self.luck, amount) },
        }
    }
    fn apply_buffs(ref self: UStats, buffs: @TStats<i8>) {
        self.strength = add_buff(self.strength, *buffs.strength);
        self.vitality = add_buff(self.vitality, *buffs.vitality);
        self.dexterity = add_buff(self.dexterity, *buffs.dexterity);
        self.luck = add_buff(self.luck, *buffs.luck);
    }
    fn get_max_health(self: @UStats) -> u8 {
        *self.vitality + STARTING_HEALTH
    }
}


#[generate_trait]
impl TStatsImpl<T, +Drop<T>, +Copy<T>> of TStatsTrait<T> {
    fn get_stat(self: @TStats<T>, stat: StatTypes) -> T {
        match stat {
            StatTypes::Strength => *self.strength,
            StatTypes::Vitality => *self.vitality,
            StatTypes::Dexterity => *self.dexterity,
            StatTypes::Luck => *self.luck,
        }
    }

    fn set_stat(ref self: TStats<T>, stat: StatTypes, value: T) {
        match stat {
            StatTypes::Strength => { self.strength = value },
            StatTypes::Vitality => { self.vitality = value },
            StatTypes::Dexterity => { self.dexterity = value },
            StatTypes::Luck => { self.luck = value },
        }
    }
}

impl TStatsAdd<T, +Add<T>, +Drop<T>> of Add<TStats<T>> {
    fn add(lhs: TStats<T>, rhs: TStats<T>) -> TStats<T> {
        TStats {
            strength: lhs.strength + rhs.strength,
            vitality: lhs.vitality + rhs.vitality,
            dexterity: lhs.dexterity + rhs.dexterity,
            luck: lhs.luck + rhs.luck,
        }
    }
}

impl TStatsSum<T, +Add<T>, +Drop<T>, +Zeroable<T>> = SumTArray<TStats<T>>;

impl TStatsAddEq<T, +AddAssign<T, T>, +Drop<T>> of AddAssign<TStats<T>, TStats<T>> {
    fn add_assign(ref self: TStats<T>, rhs: TStats<T>) {
        self.strength += rhs.strength;
        self.vitality += rhs.vitality;
        self.dexterity += rhs.dexterity;
        self.luck += rhs.luck;
    }
}


impl TStatsSaturatingSub<T, +SaturatingSub<T>, +Drop<T>> of SaturatingSub<TStats<T>> {
    fn saturating_sub(self: TStats<T>, other: TStats<T>) -> TStats<T> {
        TStats {
            strength: self.strength.saturating_sub(other.strength),
            vitality: self.vitality.saturating_sub(other.vitality),
            dexterity: self.dexterity.saturating_sub(other.dexterity),
            luck: self.luck.saturating_sub(other.luck),
        }
    }
}

impl TSaturatingAdd<T, +SaturatingAdd<T>, +Drop<T>> of SaturatingAdd<TStats<T>> {
    fn saturating_add(self: TStats<T>, other: TStats<T>) -> TStats<T> {
        TStats {
            strength: self.strength.saturating_add(other.strength),
            vitality: self.vitality.saturating_add(other.vitality),
            dexterity: self.dexterity.saturating_add(other.dexterity),
            luck: self.luck.saturating_add(other.luck),
        }
    }
}


impl TStatsSub<T, +Sub<T>, +Drop<T>> of Sub<TStats<T>> {
    fn sub(lhs: TStats<T>, rhs: TStats<T>) -> TStats<T> {
        return TStats {
            strength: lhs.strength - rhs.strength,
            vitality: lhs.vitality - rhs.vitality,
            dexterity: lhs.dexterity - rhs.dexterity,
            luck: lhs.luck - rhs.luck,
        };
    }
}

impl TStatsMul<T, +Mul<T>, +Drop<T>> of Mul<TStats<T>> {
    fn mul(lhs: TStats<T>, rhs: TStats<T>) -> TStats<T> {
        return TStats {
            strength: lhs.strength * rhs.strength,
            vitality: lhs.vitality * rhs.vitality,
            dexterity: lhs.dexterity * rhs.dexterity,
            luck: lhs.luck * rhs.luck,
        };
    }
}

impl TStatsDiv<T, +Div<T>, +Drop<T>> of Div<TStats<T>> {
    fn div(lhs: TStats<T>, rhs: TStats<T>) -> TStats<T> {
        return TStats {
            strength: lhs.strength / rhs.strength,
            vitality: lhs.vitality / rhs.vitality,
            dexterity: lhs.dexterity / rhs.dexterity,
            luck: lhs.luck / rhs.luck,
        };
    }
}

impl TStatsIntoTStata<
    T, S, +Into<T, S>, +Copy<T>, +Drop<S>, +Drop<T>
> of Into<TStats<T>, TStats<S>> {
    fn into(self: TStats<T>) -> TStats<S> {
        TStats {
            strength: self.strength.into(),
            vitality: self.vitality.into(),
            dexterity: self.dexterity.into(),
            luck: self.luck.into(),
        }
    }
}

impl TStatsSaturatingIntoTStats<
    T, S, +SaturatingInto<T, S>, +Drop<T>, +Copy<T>, +Drop<S>
> of SaturatingInto<TStats<T>, TStats<S>> {
    fn saturating_into(self: TStats<T>) -> TStats<S> {
        TStats {
            strength: self.strength.saturating_into(),
            vitality: self.vitality.saturating_into(),
            dexterity: self.dexterity.saturating_into(),
            luck: self.luck.saturating_into(),
        }
    }
}


impl StatsDisplayImpl<T, +Debug<T>, +Drop<T>, +Copy<T>> of Display<TStats<T>> {
    fn fmt(self: @TStats<T>, ref f: Formatter) -> Result<(), Error> {
        write!(
            f,
            "strength: {:?}, vitality: {:?}, dexterity: {:?}, luck: {:?}",
            *self.strength,
            *self.vitality,
            *self.dexterity,
            *self.luck
        )
    }
}
impl StatsDebugImpl<T, +Display<TStats<T>>> of Debug<TStats<T>> {
    fn fmt(self: @TStats<T>, ref f: Formatter) -> Result<(), Error> {
        Display::fmt(self, ref f)
    }
}

