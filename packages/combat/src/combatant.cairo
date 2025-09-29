use ba_loadout::attack::{Affect, Damage, DamageType};
use ba_loadout::attributes::{
    AbilityMods, Attributes, MAX_ABILITY_SCORE, MAX_TEMP_ABILITY_SCORE, MIN_TEMP_ABILITY_SCORE,
    ResistanceMods, Resistances, Vulnerabilities, VulnerabilityMods,
};
use ba_utils::{IntoRange, Randomness, RandomnessTrait};
use core::cmp::{max, min};
use core::num::traits::{SaturatingAdd, SaturatingSub, WideMul, Zero};
use sai_core_utils::SaturatingInto;
use sai_packing::shifts::*;
use sai_packing::{MaskDowncast, ShiftCast};
use starknet::storage::StorageNodeDeref;
use starknet::storage_access::StorePacking;
use crate::calculations::{
    apply_luck_modifier, combine_resistance, combine_resistance_temp, damage_calculation,
    did_critical, get_new_stun_chance, increase_resistance,
};
use crate::result::{
    AbilitiesResult, AbilitiesTempResult, AffectResult, DamageResult, VitalityResult,
    VitalityTempResult,
};

const BASE_HEALTH: u8 = 100;

#[derive(Drop, Copy, Serde, Schema, Introspect, Default)]
pub struct CombatantState {
    pub health: u8,
    pub stun_chance: u8,
    pub block: u8,
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
    pub strength_temp: i8,
    pub vitality_temp: i8,
    pub dexterity_temp: i8,
    pub luck_temp: i8,
    pub bludgeon_resistance_temp: i8,
    pub magic_resistance_temp: i8,
    pub pierce_resistance_temp: i8,
    pub bludgeon_vulnerability_temp: i16,
    pub magic_vulnerability_temp: i16,
    pub pierce_vulnerability_temp: i16,
}


impl UAbilityStorePacking of StorePacking<CombatantState, u128> {
    fn pack(value: CombatantState) -> u128 {
        value.strength.into()
            + ShiftCast::const_cast::<SHIFT_1B>(value.vitality)
            + ShiftCast::const_cast::<SHIFT_2B>(value.dexterity)
            + ShiftCast::const_cast::<SHIFT_3B>(value.luck)
            + ShiftCast::const_cast::<SHIFT_4B>(value.bludgeon_resistance)
            + ShiftCast::const_cast::<SHIFT_5B>(value.magic_resistance)
            + ShiftCast::const_cast::<SHIFT_6B>(value.pierce_resistance)
            + ShiftCast::const_cast::<SHIFT_7B>(value.bludgeon_vulnerability)
            + ShiftCast::const_cast::<SHIFT_9B>(value.magic_vulnerability)
            + ShiftCast::const_cast::<SHIFT_11B>(value.pierce_vulnerability)
            + ShiftCast::const_cast::<SHIFT_13B>(value.health)
            + ShiftCast::const_cast::<SHIFT_14B>(value.stun_chance)
    }

    fn unpack(value: u128) -> CombatantState {
        CombatantState {
            strength: MaskDowncast::cast(value),
            vitality: ShiftCast::const_unpack::<SHIFT_1B>(value),
            dexterity: ShiftCast::const_unpack::<SHIFT_2B>(value),
            luck: ShiftCast::const_unpack::<SHIFT_3B>(value),
            bludgeon_resistance: ShiftCast::const_unpack::<SHIFT_4B>(value),
            magic_resistance: ShiftCast::const_unpack::<SHIFT_5B>(value),
            pierce_resistance: ShiftCast::const_unpack::<SHIFT_6B>(value),
            bludgeon_vulnerability: ShiftCast::const_unpack::<SHIFT_7B>(value),
            magic_vulnerability: ShiftCast::const_unpack::<SHIFT_9B>(value),
            pierce_vulnerability: ShiftCast::const_unpack::<SHIFT_11B>(value),
            health: ShiftCast::const_unpack::<SHIFT_12B>(value),
            stun_chance: ShiftCast::const_unpack::<SHIFT_13B>(value),
            strength_temp: Zero::zero(),
            vitality_temp: Zero::zero(),
            dexterity_temp: Zero::zero(),
            luck_temp: Zero::zero(),
            bludgeon_resistance_temp: Zero::zero(),
            magic_resistance_temp: Zero::zero(),
            pierce_resistance_temp: Zero::zero(),
            bludgeon_vulnerability_temp: Zero::zero(),
            magic_vulnerability_temp: Zero::zero(),
            pierce_vulnerability_temp: Zero::zero(),
            block: 0,
        }
    }
}


pub fn get_max_health(vitality: u8) -> u8 {
    BASE_HEALTH + vitality
}

pub fn get_max_health_percent(vitality: u8, percent: u8) -> u8 {
    (percent * get_max_health(vitality).into() / 100).saturating_into()
}

impl AbilitiesIntoCombatantState of Into<Attributes, CombatantState> {
    fn into(self: Attributes) -> CombatantState {
        CombatantState {
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
            health: get_max_health(self.vitality),
            strength_temp: Zero::zero(),
            vitality_temp: Zero::zero(),
            dexterity_temp: Zero::zero(),
            luck_temp: Zero::zero(),
            bludgeon_resistance_temp: Zero::zero(),
            magic_resistance_temp: Zero::zero(),
            pierce_resistance_temp: Zero::zero(),
            bludgeon_vulnerability_temp: Zero::zero(),
            magic_vulnerability_temp: Zero::zero(),
            pierce_vulnerability_temp: Zero::zero(),
            stun_chance: Zero::zero(),
            block: Zero::zero(),
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

fn modify_resistance_temp(ref value: i8, change: i8) -> i8 {
    value = combine_resistance_temp(value, change);
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

fn combine_temp(value: u8, temp: i8) -> u8 {
    min((value.saturating_into() + temp).saturating_into(), MAX_ABILITY_SCORE)
}

fn combine_vulnerability(value: u16, temp: i16) -> u16 {
    (Into::<_, i32>::into(value) + temp.into()).saturating_into()
}

#[generate_trait]
pub impl CombatantStateImpl of CombatantStateTrait {
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
        attacker_state: @CombatantState,
        ref randomness: Randomness,
    ) -> DamageResult {
        let critical = did_critical(damage.critical, attacker_state.luck(), ref randomness);
        let mut hp = damage_calculation(damage.power, attacker_state.strength(), critical);
        let affinity = self.affinity(damage.damage_type);
        let hp = match affinity != 100 {
            true => (hp.wide_mul(affinity) / 100).saturating_into(),
            false => hp.saturating_into(),
        };
        self.health = self.health.saturating_sub(hp);
        DamageResult { hp, critical }
    }


    fn modify_health(ref self: CombatantState, change: i8) -> u8 {
        let health: i16 = self.health.try_into().unwrap();
        self
            .health =
                min(self.max_health(), health.saturating_add(change.into()).saturating_into());
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
        let bludgeon = self.modify_bludgeon_resistance(mods.bludgeon);
        let magic = self.modify_magic_resistance(mods.magic);
        let pierce = self.modify_pierce_resistance(mods.pierce);
        Resistances { bludgeon, magic, pierce }
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

    fn modify_bludgeon_resistance_temp(ref self: CombatantState, amount: i8) {
        modify_resistance_temp(ref self.bludgeon_resistance_temp, amount);
    }

    fn modify_magic_resistance_temp(ref self: CombatantState, amount: i8) {
        modify_resistance_temp(ref self.magic_resistance_temp, amount);
    }

    fn modify_pierce_resistance_temp(ref self: CombatantState, amount: i8) {
        modify_resistance_temp(ref self.pierce_resistance_temp, amount);
    }

    fn modify_resistances_temp(ref self: CombatantState, mods: ResistanceMods) {
        self.modify_bludgeon_resistance_temp(mods.bludgeon);
        self.modify_magic_resistance_temp(mods.magic);
        self.modify_pierce_resistance_temp(mods.pierce);
    }

    fn modify_bludgeon_vulnerability_temp(ref self: CombatantState, amount: i16) {
        let new: i32 = self.bludgeon_resistance_temp.into() + amount.into();
        self.bludgeon_vulnerability_temp = new.saturating_into();
    }

    fn modify_magic_vulnerability_temp(ref self: CombatantState, amount: i16) {
        let new: i32 = self.magic_resistance_temp.into() + amount.into();
        self.magic_vulnerability_temp = new.saturating_into();
    }

    fn modify_pierce_vulnerability_temp(ref self: CombatantState, amount: i16) {
        let new: i32 = self.pierce_resistance_temp.into() + amount.into();
        self.pierce_vulnerability_temp = new.saturating_into();
    }

    fn modify_vulnerabilities_temp(ref self: CombatantState, mods: VulnerabilityMods) {
        self.modify_bludgeon_vulnerability_temp(mods.bludgeon);
        self.modify_magic_vulnerability_temp(mods.magic);
        self.modify_pierce_vulnerability_temp(mods.pierce);
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

    fn cap_health(ref self: CombatantState) -> u8 {
        self.health = min(self.max_health(), self.health);
        self.health
    }

    fn max_health(self: @CombatantState) -> u8 {
        get_max_health(*self.vitality)
    }

    fn run_stun(ref self: CombatantState, ref randomness: Randomness) -> bool {
        let stun_chance: u8 = apply_luck_modifier(self.stun_chance, 100 - self.luck);
        self.stun_chance = 0;
        randomness.get(255) < stun_chance
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
        attacker_state: @CombatantState,
        ref randomness: Randomness,
    ) -> AffectResult {
        match affect {
            Affect::None => AffectResult::None,
            Affect::Strength(amount) => AffectResult::Strength(self.modify_strength(amount)),
            Affect::Vitality(amount) => AffectResult::Vitality(self.modify_vitality(amount)),
            Affect::Dexterity(amount) => AffectResult::Dexterity(self.modify_dexterity(amount)),
            Affect::Luck(amount) => AffectResult::Luck(self.modify_luck(amount)),
            Affect::Abilities(mods) => AffectResult::Abilities(self.modify_abilities(mods)),
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
                AffectResult::Damage(self.apply_damage(damage, attacker_state, ref randomness))
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
            Affect::BludgeonResistanceTemp(amount) => {
                self.modify_bludgeon_resistance_temp(amount);
                AffectResult::BludgeonResistanceTemp(amount)
            },
            Affect::MagicResistanceTemp(amount) => {
                self.modify_magic_resistance_temp(amount);
                AffectResult::MagicResistanceTemp(amount)
            },
            Affect::PierceResistanceTemp(amount) => {
                self.modify_pierce_resistance_temp(amount);
                AffectResult::PierceResistanceTemp(amount)
            },
            Affect::ResistancesTemp(mods) => {
                self.modify_resistances_temp(mods);
                AffectResult::ResistancesTemp(mods)
            },
            Affect::BludgeonVulnerabilityTemp(amount) => {
                self.modify_bludgeon_vulnerability_temp(amount);
                AffectResult::BludgeonVulnerabilityTemp(amount)
            },
            Affect::MagicVulnerabilityTemp(amount) => {
                self.modify_magic_vulnerability_temp(amount);
                AffectResult::MagicVulnerabilityTemp(amount)
            },
            Affect::PierceVulnerabilityTemp(amount) => {
                self.modify_pierce_vulnerability_temp(amount);
                AffectResult::PierceVulnerabilityTemp(amount)
            },
            Affect::VulnerabilitiesTemp(mods) => {
                self.modify_vulnerabilities_temp(mods);
                AffectResult::VulnerabilitiesTemp(mods)
            },
        }
    }
}

