use ba_loadout::action::{Affect, Damage, DamageType};
use ba_loadout::attributes::{
    AbilityMods, Attributes, MAX_ABILITY_SCORE, MAX_TEMP_ABILITY_SCORE, MIN_TEMP_ABILITY_SCORE,
    ResistanceMods, Resistances, Vulnerabilities, VulnerabilityMods,
};
use ba_utils::{IntoRange, Randomness, RandomnessTrait};
use core::cmp::{max, min};
use core::num::traits::{Pow, SaturatingAdd, SaturatingSub, WideMul, Zero};
use sai_core_utils::SaturatingInto;
use sai_packing::masks::*;
use sai_packing::shifts::*;
use sai_packing::{MaskDowncast, ShiftCast};
use starknet::storage::StorageNodeDeref;
use starknet::storage_access::StorePacking;
use crate::calculations::{
    combine_resistance, combine_resistance_temp, damage_calculation, did_critical,
    get_new_stun_chance, increase_resistance,
};
use crate::result::{
    AbilitiesResult, AbilitiesTempResult, AffectResult, DamageResult, VitalityResult,
    VitalityTempResult,
};

pub const BASE_HEALTH: u16 = 100;


#[derive(Drop, Copy, Serde, Schema, Introspect, Default)]
pub struct CombatantState {
    pub strength: u16,
    pub vitality: u16,
    pub dexterity: u16,
    pub luck: u16,
    pub stun_modifier: u32,
    pub damage_modifier: u32,
    pub bludgeon_modifier: u32,
    pub magic_modifier: u32,
    pub pierce_modifier: u32,
    pub health: u16,
    pub stun_chance: u16,
    /// temp values
    pub strength_temp: i32,
    pub vitality_temp: i32,
    pub dexterity_temp: i32,
    pub luck_temp: i32,
    pub stun_modifier_temp: u32,
    pub damage_modifier_temp: u32,
    pub bludgeon_modifier_temp: u32,
    pub magic_modifier_temp: u32,
    pub pierce_modifier_temp: u32,
    pub health_temp: i32,
}


impl UAbilityStorePacking of StorePacking<CombatantState, felt252> {
    fn pack(value: CombatantState) -> felt252 {
        value.strength.into()
            + SHIFT_2B_FELT252 * value.vitality.into()
            + SHIFT_4B_FELT252 * value.dexterity.into()
            + SHIFT_6B_FELT252 * value.luck.into()
            + SHIFT_8B_FELT252 * value.stun_modifier.into()
            + SHIFT_95b_FELT252 * value.bludgeon_modifier.into()
            + SHIFT_126b_FELT252 * value.magic_modifier.into()
            + SHIFT_157b_FELT252 * value.pierce_modifier.into()
            + SHIFT_188b_FELT252 * value.damage_modifier.into()
            + SHIFT_219b_FELT252 * value.health.into()
            + SHIFT_235b_FELT252 * value.stun_chance.into()
    }

    fn unpack(value: felt252) -> CombatantState {
        let value: u256 = value.into();
        let u256 { low, high } = value;
        CombatantState {
            strength: MaskDowncast::cast(low),
            vitality: ShiftCast::const_unpack::<SHIFT_2B>(low),
            dexterity: ShiftCast::const_unpack::<SHIFT_4B>(low),
            luck: ShiftCast::const_unpack::<SHIFT_6B>(low),
            stun_modifier: ((low / SHIFT_8B) & MASK_31b_U128).try_into().unwrap(),
            bludgeon_modifier: ((low / SHIFT_95b) & MASK_31b_U128).try_into().unwrap(),
            magic_modifier: ((value / SHIFT_126b_U256) & MASK_31b_U256).try_into().unwrap(),
            pierce_modifier: ((high / SHIFT_29b_U128) & MASK_31b_U128).try_into().unwrap(),
            damage_modifier: ((high / SHIFT_60b_U128) & MASK_31b_U128).try_into().unwrap(),
            stun_chance: ShiftCast::const_unpack::<SHIFT_91b_U128>(high),
            health: ShiftCast::const_unpack::<SHIFT_107b_U128>(high),
            health_temp: 0,
            strength_temp: 0,
            vitality_temp: 0,
            dexterity_temp: 0,
            luck_temp: 0,
            stun_modifier_temp: 0,
            damage_modifier_temp: 0,
            bludgeon_modifier_temp: 0,
            magic_modifier_temp: 0,
            pierce_modifier_temp: 0,
        }
    }
}


pub fn get_max_health(vitality: u16) -> u16 {
    BASE_HEALTH + vitality
}

pub fn get_max_health_percent(vitality: u16, percent: u8) -> u8 {
    (get_max_health(vitality).wide_mul(percent.into()) / 100_u32).saturating_into()
}

impl AbilitiesIntoCombatantState of Into<Attributes, CombatantState> {
    fn into(self: Attributes) -> CombatantState {
        CombatantState {
            strength: self.strength,
            vitality: self.vitality,
            dexterity: self.dexterity,
            luck: self.luck,
            stun_modifier: self.stun_modifier,
            damage_modifier: self.damage_modifier,
            bludgeon_modifier: self.bludgeon_modifier,
            magic_modifier: self.magic_modifier,
            pierce_modifier: self.pierce_modifier,
            health: get_max_health(self.vitality),
            stun_chance: 0,
            strength_temp: 0,
            vitality_temp: 0,
            dexterity_temp: 0,
            luck_temp: 0,
            stun_modifier_temp: 0,
            damage_modifier_temp: 0,
            bludgeon_modifier_temp: 0,
            magic_modifier_temp: 0,
            pierce_modifier_temp: 0,
            health_temp: 0,
        }
    }
}

fn add_ability_modifier(value: u8, modifier: i8) -> u8 {
    (Into::<_, i16>::into(value) + modifier.into()).into_range(0, MAX_ABILITY_SCORE)
}

fn add_ability_modifier_temp(value: i8, modifier: i8) -> i8 {
    max(min(value.saturating_add(modifier), MIN_TEMP_ABILITY_SCORE), MAX_TEMP_ABILITY_SCORE)
}

fn modify_ability(ref current: u8, modifier: i8) -> u8 {
    current = add_ability_modifier(current, modifier);
    current
}

fn modify_ability_temp(ref current: i8, modifier: i8) -> i8 {
    current = add_ability_modifier_temp(current, modifier);
    current
}

fn modify_resistance_temp(ref value: u32, change: u32) -> u32 {
    value = value.into() * change.into()
    value
}

fn modify_resistance<T, +Drop<T>, +Into<T, i16>>(ref value: u8, change: T) -> u8 {
    value = combine_resistance(value, change);
    value
}

fn modify_vulnerability(ref value: u16, change: i16) -> u16 {
    let new: i32 = value.into() + change.into();
    value = new.saturating_into();
    value
}

fn modify_vulnerability_temp(ref value: i16, change: i16) -> i16 {
    let new: i32 = value.into() + change.into();
    value = new.saturating_into();
    value
}

fn combine_temp(value: u8, temp: i8) -> u8 {
    min((value.saturating_into() + temp).saturating_into(), MAX_ABILITY_SCORE)
}

fn combine_vulnerability(value: u16, temp: i16) -> u16 {
    (Into::<_, i32>::into(value) + temp.into()).saturating_into()
}

#[generate_trait]
pub impl CombatantStateImpl of CombatantStateTrait {
    fn cap_health(ref self: CombatantState) {
        self.health = min(self.health, self.max_health());
    }

    fn strength(self: @CombatantState) -> u8 {
        combine_temp(*self.strength, *self.strength_temp)
    }

    fn vitality(self: @CombatantState) -> u8 {
        combine_temp(*self.vitality, *self.vitality_temp)
    }

    fn dexterity(self: @CombatantState) -> u8 {
        combine_temp(*self.dexterity, *self.dexterity_temp)
    }

    fn luck(self: @CombatantState) -> u8 {
        combine_temp(*self.luck, *self.luck_temp)
    }

    fn stun_resistance(self: @CombatantState) -> u8 {
        combine_resistance(*self.stun_resistance, *self.stun_resistance_temp)
    }

    fn bludgeon_resistance(self: @CombatantState) -> u8 {
        combine_resistance(*self.bludgeon_resistance, *self.bludgeon_resistance_temp)
    }

    fn magic_resistance(self: @CombatantState) -> u8 {
        combine_resistance(*self.magic_resistance, *self.magic_resistance_temp)
    }

    fn pierce_resistance(self: @CombatantState) -> u8 {
        combine_resistance(*self.pierce_resistance, *self.pierce_resistance_temp)
    }

    fn bludgeon_vulnerability(self: @CombatantState) -> u16 {
        combine_vulnerability(*self.bludgeon_vulnerability, *self.bludgeon_vulnerability_temp)
    }

    fn magic_vulnerability(self: @CombatantState) -> u16 {
        combine_vulnerability(*self.magic_vulnerability, *self.magic_vulnerability_temp)
    }

    fn pierce_vulnerability(self: @CombatantState) -> u16 {
        combine_vulnerability(*self.pierce_vulnerability, *self.pierce_vulnerability_temp)
    }


    fn apply_damage(
        ref self: CombatantState,
        damage: Damage,
        actor_state: @CombatantState,
        ref randomness: Randomness,
    ) -> DamageResult {
        let critical = did_critical(damage.critical, actor_state.luck(), ref randomness);
        let mut hp = damage_calculation(damage.power, actor_state.strength(), critical);
        let affinity = self.affinity(damage.damage_type);
        let hp = match affinity != 100 {
            true => (hp.wide_mul(affinity) / 100).saturating_into(),
            false => hp.saturating_into(),
        };
        self.health = self.health.saturating_sub(hp);
        DamageResult { hp, critical }
    }
    fn set_and_regen_health(ref self: CombatantState, health: u8, amount: u8) {
        self.health = health;
        self.health = min(self.health.saturating_add(amount), self.max_health());
    }

    fn modify_health(ref self: CombatantState, change: i16) -> u8 {
        let health: i16 = self.health.try_into().unwrap();
        self.health = min(self.max_health(), health.saturating_add(change).saturating_into());
        self.health
    }

    fn modify_strength(ref self: CombatantState, amount: i8) -> u8 {
        modify_ability(ref self.strength, amount)
    }

    fn modify_vitality(ref self: CombatantState, amount: i8) -> VitalityResult {
        let vitality = modify_ability(ref self.vitality, amount);
        self.cap_health();
        VitalityResult { vitality, health: self.health }
    }

    fn modify_dexterity(ref self: CombatantState, amount: i8) -> u8 {
        modify_ability(ref self.dexterity, amount)
    }

    fn modify_luck(ref self: CombatantState, amount: i8) -> u8 {
        modify_ability(ref self.luck, amount)
    }

    fn modify_abilities(ref self: CombatantState, mods: AbilityMods) -> AbilitiesResult {
        let strength = self.modify_strength(mods.strength);
        self.modify_vitality(mods.vitality);
        let dexterity = self.modify_dexterity(mods.dexterity);
        let luck = self.modify_luck(mods.luck);
        AbilitiesResult { strength, vitality: self.vitality, dexterity, luck, health: self.health }
    }

    fn modify_stun_resistance(ref self: CombatantState, amount: i8) -> u8 {
        modify_resistance(ref self.stun_resistance, amount)
    }

    fn modify_bludgeon_resistance(ref self: CombatantState, amount: i8) -> u8 {
        modify_resistance(ref self.bludgeon_resistance, amount)
    }

    fn modify_magic_resistance(ref self: CombatantState, amount: i8) -> u8 {
        modify_resistance(ref self.magic_resistance, amount)
    }

    fn modify_pierce_resistance(ref self: CombatantState, amount: i8) -> u8 {
        modify_resistance(ref self.pierce_resistance, amount)
    }

    fn modify_resistances(ref self: CombatantState, mods: ResistanceMods) -> Resistances {
        let stun = self.modify_stun_resistance(mods.stun);
        let bludgeon = self.modify_bludgeon_resistance(mods.bludgeon);
        let magic = self.modify_magic_resistance(mods.magic);
        let pierce = self.modify_pierce_resistance(mods.pierce);
        Resistances { stun, bludgeon, magic, pierce }
    }

    fn modify_bludgeon_vulnerability(ref self: CombatantState, amount: i16) -> u16 {
        modify_vulnerability(ref self.bludgeon_vulnerability, amount)
    }

    fn modify_magic_vulnerability(ref self: CombatantState, amount: i16) -> u16 {
        modify_vulnerability(ref self.magic_vulnerability, amount)
    }

    fn modify_pierce_vulnerability(ref self: CombatantState, amount: i16) -> u16 {
        modify_vulnerability(ref self.pierce_vulnerability, amount)
    }

    fn modify_vulnerabilities(
        ref self: CombatantState, mods: VulnerabilityMods,
    ) -> Vulnerabilities {
        let bludgeon = self.modify_bludgeon_vulnerability(mods.bludgeon);
        let magic = self.modify_magic_vulnerability(mods.magic);
        let pierce = self.modify_pierce_vulnerability(mods.pierce);
        Vulnerabilities { bludgeon, magic, pierce }
    }

    fn modify_strength_temp(ref self: CombatantState, amount: i8) -> i8 {
        modify_ability_temp(ref self.strength_temp, amount)
    }

    fn modify_vitality_temp(ref self: CombatantState, amount: i8) -> VitalityTempResult {
        let vitality = modify_ability_temp(ref self.vitality_temp, amount);
        self.cap_health();
        VitalityTempResult { vitality: vitality, health: self.health }
    }

    fn modify_dexterity_temp(ref self: CombatantState, amount: i8) -> i8 {
        modify_ability_temp(ref self.dexterity_temp, amount)
    }

    fn modify_luck_temp(ref self: CombatantState, amount: i8) -> i8 {
        modify_ability_temp(ref self.luck_temp, amount)
    }

    fn modify_abilities_temp(ref self: CombatantState, mods: AbilityMods) -> AbilitiesTempResult {
        let strength = self.modify_strength_temp(mods.strength);
        self.modify_vitality_temp(mods.vitality);
        let dexterity = self.modify_dexterity_temp(mods.dexterity);
        let luck = self.modify_luck_temp(mods.luck);
        AbilitiesTempResult {
            strength, vitality: self.vitality_temp, dexterity, luck, health: self.health,
        }
    }
    fn modify_stun_resistance_temp(ref self: CombatantState, amount: i8) -> i8 {
        modify_resistance_temp(ref self.stun_resistance_temp, amount)
    }

    fn modify_bludgeon_resistance_temp(ref self: CombatantState, amount: i8) -> i8 {
        modify_resistance_temp(ref self.bludgeon_resistance_temp, amount)
    }

    fn modify_magic_resistance_temp(ref self: CombatantState, amount: i8) -> i8 {
        modify_resistance_temp(ref self.magic_resistance_temp, amount)
    }

    fn modify_pierce_resistance_temp(ref self: CombatantState, amount: i8) -> i8 {
        modify_resistance_temp(ref self.pierce_resistance_temp, amount)
    }

    fn modify_resistances_temp(ref self: CombatantState, mods: ResistanceMods) -> ResistanceMods {
        ResistanceMods {
            stun: self.modify_stun_resistance_temp(mods.stun),
            bludgeon: self.modify_bludgeon_resistance_temp(mods.bludgeon),
            magic: self.modify_magic_resistance_temp(mods.magic),
            pierce: self.modify_pierce_resistance_temp(mods.pierce),
        }
    }

    fn modify_bludgeon_vulnerability_temp(ref self: CombatantState, amount: i16) -> i16 {
        modify_vulnerability_temp(ref self.bludgeon_vulnerability_temp, amount)
    }

    fn modify_magic_vulnerability_temp(ref self: CombatantState, amount: i16) -> i16 {
        modify_vulnerability_temp(ref self.magic_vulnerability_temp, amount)
    }

    fn modify_pierce_vulnerability_temp(ref self: CombatantState, amount: i16) -> i16 {
        modify_vulnerability_temp(ref self.pierce_vulnerability_temp, amount)
    }


    fn modify_vulnerabilities_temp(
        ref self: CombatantState, mods: VulnerabilityMods,
    ) -> VulnerabilityMods {
        VulnerabilityMods {
            bludgeon: self.modify_bludgeon_vulnerability_temp(mods.bludgeon),
            magic: self.modify_magic_vulnerability_temp(mods.magic),
            pierce: self.modify_pierce_vulnerability_temp(mods.pierce),
        }
    }


    fn resistance(self: @CombatantState, damage_type: DamageType) -> u8 {
        let type_resistance = match damage_type {
            DamageType::None => Zero::zero(),
            DamageType::Bludgeon => *self.bludgeon_resistance,
            DamageType::Magic => *self.magic_resistance,
            DamageType::Pierce => *self.pierce_resistance,
        };
        increase_resistance(*self.block, type_resistance)
    }

    fn affinity(self: @CombatantState, damage_type: DamageType) -> u16 {
        let (resistance, vulnerability) = match damage_type {
            DamageType::None => (Zero::zero(), Zero::zero()),
            DamageType::Bludgeon => (self.bludgeon_resistance(), self.bludgeon_vulnerability()),
            DamageType::Magic => (self.magic_resistance(), self.magic_vulnerability()),
            DamageType::Pierce => (self.pierce_resistance(), self.pierce_vulnerability()),
        };
        let resistance: i32 = increase_resistance(*self.block, resistance).into();
        let vulnerability: i32 = vulnerability.into();
        (100 + vulnerability - resistance - vulnerability * resistance / 100).saturating_into()
    }

    fn max_health(self: @CombatantState) -> u8 {
        get_max_health(*self.vitality)
    }

    fn set_health(ref self: CombatantState, health: u8) -> u8 {
        self.health = health;
        self.health
    }

    fn floor_health(ref self: CombatantState, health: u8) -> u8 {
        self.set_health(max(self.health, health))
    }

    fn ceil_health(ref self: CombatantState, health: u8) -> u8 {
        self.set_health(min(self.health, health))
    }

    fn percentage_of_max_health(self: @CombatantState, percent: u8) -> u8 {
        (self.max_health().wide_mul(percent) / 100).saturating_into()
    }

    fn signed_percentage_of_max_health(self: @CombatantState, percent: i8) -> i16 {
        (self.max_health().into() * percent.into() / 100)
    }

    fn modify_health_percent(ref self: CombatantState, percent: i8) -> u8 {
        self
            .set_health(
                (self.health.into() + self.signed_percentage_of_max_health(percent))
                    .saturating_into(),
            )
    }

    fn floor_health_percent(ref self: CombatantState, percent: u8) -> u8 {
        self.floor_health(self.percentage_of_max_health(percent))
    }

    fn ceil_health_percent(ref self: CombatantState, percent: u8) -> u8 {
        self.ceil_health(self.percentage_of_max_health(percent))
    }

    fn set_health_percent(ref self: CombatantState, percent: u8) -> u8 {
        self.set_health(self.percentage_of_max_health(percent))
    }

    fn run_stun(ref self: CombatantState, ref randomness: Randomness) -> bool {
        let stun_chance: u8 = (self.stun_chance.wide_mul(100 - self.stun_resistance()) / 100)
            .try_into()
            .unwrap();
        self.stun_chance = 0;
        randomness.get(100) < stun_chance
    }

    fn increase_stun(ref self: CombatantState, stun: u8) {
        self.stun_chance = get_new_stun_chance(self.stun_chance, stun)
    }

    fn increase_block(ref self: CombatantState, block: u8) -> u8 {
        self.block = increase_resistance(self.block, block);
        self.block
    }

    fn apply_affect(
        ref self: CombatantState,
        affect: Affect,
        actor_state: @CombatantState,
        ref randomness: Randomness,
    ) -> AffectResult {
        match affect {
            Affect::None => AffectResult::None,
            Affect::Strength(amount) => AffectResult::Strength(self.modify_strength(amount)),
            Affect::Vitality(amount) => AffectResult::Vitality(self.modify_vitality(amount)),
            Affect::Dexterity(amount) => AffectResult::Dexterity(self.modify_dexterity(amount)),
            Affect::Luck(amount) => AffectResult::Luck(self.modify_luck(amount)),
            Affect::Abilities(mods) => AffectResult::Abilities(self.modify_abilities(mods)),
            Affect::StunResistance(amount) => AffectResult::StunResistance(
                self.modify_stun_resistance(amount),
            ),
            Affect::BludgeonResistance(amount) => AffectResult::BludgeonResistance(
                self.modify_bludgeon_resistance(amount),
            ),
            Affect::MagicResistance(amount) => AffectResult::MagicResistance(
                self.modify_magic_resistance(amount),
            ),
            Affect::PierceResistance(amount) => AffectResult::PierceResistance(
                self.modify_pierce_resistance(amount),
            ),
            Affect::Resistances(mods) => AffectResult::Resistances(self.modify_resistances(mods)),
            Affect::BludgeonVulnerability(amount) => AffectResult::BludgeonVulnerability(
                self.modify_bludgeon_vulnerability(amount),
            ),
            Affect::MagicVulnerability(amount) => AffectResult::MagicVulnerability(
                self.modify_magic_vulnerability(amount),
            ),
            Affect::PierceVulnerability(amount) => AffectResult::PierceVulnerability(
                self.modify_pierce_vulnerability(amount),
            ),
            Affect::Vulnerabilities(mods) => AffectResult::Vulnerabilities(
                self.modify_vulnerabilities(mods),
            ),
            Affect::Damage(damage) => {
                AffectResult::Damage(self.apply_damage(damage, actor_state, ref randomness))
            },
            Affect::Stun(stun) => {
                self.increase_stun(stun);
                AffectResult::Stun(stun)
            },
            Affect::Health(health) => AffectResult::Health(self.modify_health(health)),
            Affect::Block(block) => AffectResult::Block(self.increase_block(block)),
            Affect::StrengthTemp(amount) => AffectResult::StrengthTemp(
                self.modify_strength_temp(amount),
            ),
            Affect::VitalityTemp(amount) => AffectResult::VitalityTemp(
                self.modify_vitality_temp(amount),
            ),
            Affect::DexterityTemp(amount) => AffectResult::DexterityTemp(
                self.modify_dexterity_temp(amount),
            ),
            Affect::LuckTemp(amount) => AffectResult::LuckTemp(self.modify_luck_temp(amount)),
            Affect::AbilitiesTemp(mods) => AffectResult::AbilitiesTemp(
                self.modify_abilities_temp(mods),
            ),
            Affect::StunResistanceTemp(amount) => AffectResult::StunResistanceTemp(
                self.modify_stun_resistance_temp(amount),
            ),
            Affect::BludgeonResistanceTemp(amount) => {
                AffectResult::BludgeonResistanceTemp(self.modify_bludgeon_resistance_temp(amount))
            },
            Affect::MagicResistanceTemp(amount) => {
                AffectResult::MagicResistanceTemp(self.modify_magic_resistance_temp(amount))
            },
            Affect::PierceResistanceTemp(amount) => {
                AffectResult::PierceResistanceTemp(self.modify_pierce_resistance_temp(amount))
            },
            Affect::ResistancesTemp(mods) => {
                AffectResult::ResistancesTemp(self.modify_resistances_temp(mods))
            },
            Affect::BludgeonVulnerabilityTemp(amount) => {
                AffectResult::BludgeonVulnerabilityTemp(
                    self.modify_bludgeon_vulnerability_temp(amount),
                )
            },
            Affect::MagicVulnerabilityTemp(amount) => {
                AffectResult::MagicVulnerabilityTemp(self.modify_magic_vulnerability_temp(amount))
            },
            Affect::PierceVulnerabilityTemp(amount) => {
                AffectResult::PierceVulnerabilityTemp(self.modify_pierce_vulnerability_temp(amount))
            },
            Affect::VulnerabilitiesTemp(mods) => {
                AffectResult::VulnerabilitiesTemp(self.modify_vulnerabilities_temp(mods))
            },
            Affect::SetHealth(health) => AffectResult::SetHealth(self.set_health(health)),
            Affect::FloorHealth(health) => AffectResult::FloorHealth(self.floor_health(health)),
            Affect::CeilHealth(health) => AffectResult::CeilHealth(self.ceil_health(health)),
            Affect::HealthPercentMax(percent) => {
                AffectResult::HealthPercentMax(self.modify_health_percent(percent.into()))
            },
            Affect::SetHealthPercentMax(percent) => {
                AffectResult::SetHealthPercentMax(self.set_health_percent(percent))
            },
            Affect::FloorHealthPercentMax(percent) => {
                AffectResult::FloorHealthPercentMax(self.floor_health_percent(percent))
            },
            Affect::CeilHealthPercentMax(percent) => {
                AffectResult::CeilHealthPercentMax(self.ceil_health_percent(percent))
            },
        }
    }
}

