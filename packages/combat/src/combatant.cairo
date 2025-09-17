use ba_loadout::attack::{Affect, Damage, DamageType};
use ba_loadout::attributes::{
    AbilityMods, Attributes, MAX_ABILITY_SCORE, ResistanceMods, VulnerabilityMods,
};
use ba_utils::{IntoRange, Randomness, RandomnessTrait};
use core::cmp::min;
use core::num::traits::{SaturatingAdd, SaturatingSub, WideMul, Zero};
use sai_core_utils::SaturatingInto;
use sai_packing::shifts::*;
use sai_packing::{MaskDowncast, ShiftCast};
use starknet::storage::StorageNodeDeref;
use starknet::storage_access::StorePacking;
use crate::calculations::{
    apply_luck_modifier, combine_resistance, damage_calculation, did_critical, get_new_stun_chance,
    increase_resistance,
};
use crate::result::{AffectResult, DamageResult};

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
}


impl UAbilityStorePacking of StorePacking<CombatantState, u128> {
    fn pack(value: CombatantState) -> u128 {
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
            + ShiftCast::cast::<SHIFT_13B>(value.health)
            + ShiftCast::cast::<SHIFT_14B>(value.stun_chance)
    }

    fn unpack(value: u128) -> CombatantState {
        CombatantState {
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
            health: ShiftCast::unpack::<SHIFT_12B>(value),
            stun_chance: ShiftCast::unpack::<SHIFT_13B>(value),
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
            stun_chance: 0,
            block: 0,
        }
    }
}

fn add_ability_modifier(value: u8, modifier: i8) -> u8 {
    (Into::<_, i16>::into(value) + modifier.into()).into_range(0, MAX_ABILITY_SCORE)
}

fn modify_ability(ref current: u8, modifier: i8) -> i8 {
    let prev_value: i8 = current.try_into().unwrap();
    current = add_ability_modifier(current, modifier);
    (current.try_into().unwrap() - prev_value)
}

fn modify_resistance<T, +Drop<T>, +Into<T, i16>>(ref value: u8, change: T) {
    value = combine_resistance(value, change);
}

#[generate_trait]
pub impl CombatantStateImpl of CombatantStateTrait {
    fn apply_damage(
        ref self: CombatantState,
        damage: Damage,
        attacker_state: @CombatantState,
        ref randomness: Randomness,
    ) -> DamageResult {
        let critical = did_critical(damage.critical, *attacker_state.luck, ref randomness);
        let mut hp = damage_calculation(damage.power, *attacker_state.strength, critical);
        let affinity = self.affinity(damage.damage_type);
        let hp = match affinity != 100 {
            true => (hp.wide_mul(affinity) / 100).saturating_into(),
            false => hp.saturating_into(),
        };
        self.health = self.health.saturating_sub(hp);
        DamageResult { hp, critical }
    }


    fn modify_health(ref self: CombatantState, health: i8) -> i16 {
        let starting_health: i16 = self.health.into();
        self
            .health =
                min(
                    self.max_health(),
                    self.health.try_into().unwrap().saturating_add(health).saturating_into(),
                );
        self.health.try_into().unwrap() - starting_health
    }

    fn modify_strength(ref self: CombatantState, amount: i8) -> i8 {
        modify_ability(ref self.strength, amount)
    }

    fn modify_vitality(ref self: CombatantState, amount: i8) -> i8 {
        let change = modify_ability(ref self.vitality, amount);
        self.cap_health();
        change
    }

    fn modify_dexterity(ref self: CombatantState, amount: i8) -> i8 {
        modify_ability(ref self.dexterity, amount)
    }

    fn modify_luck(ref self: CombatantState, amount: i8) -> i8 {
        modify_ability(ref self.luck, amount)
    }

    fn modify_abilities(ref self: CombatantState, mods: AbilityMods) {
        self.modify_strength(mods.strength);
        self.modify_vitality(mods.vitality);
        self.modify_dexterity(mods.dexterity);
        self.modify_luck(mods.luck);
    }

    fn modify_bludgeon_resistance(ref self: CombatantState, amount: i8) {
        modify_resistance(ref self.bludgeon_resistance, amount);
    }

    fn modify_magic_resistance(ref self: CombatantState, amount: i8) {
        modify_resistance(ref self.magic_resistance, amount);
    }

    fn modify_pierce_resistance(ref self: CombatantState, amount: i8) {
        modify_resistance(ref self.pierce_resistance, amount);
    }

    fn modify_resistances(ref self: CombatantState, mods: ResistanceMods) {
        self.modify_bludgeon_resistance(mods.bludgeon);
        self.modify_magic_resistance(mods.magic);
        self.modify_pierce_resistance(mods.pierce);
    }

    fn modify_bludgeon_vulnerability(ref self: CombatantState, amount: i16) {
        let new: i32 = self.bludgeon_resistance.into() + amount.into();
        self.bludgeon_vulnerability = new.saturating_into();
    }

    fn modify_magic_vulnerability(ref self: CombatantState, amount: i16) {
        let new: i32 = self.magic_resistance.into() + amount.into();
        self.magic_vulnerability = new.saturating_into();
    }

    fn modify_pierce_vulnerability(ref self: CombatantState, amount: i16) {
        let new: i32 = self.pierce_resistance.into() + amount.into();
        self.pierce_vulnerability = new.saturating_into();
    }

    fn modify_vulnerabilities(ref self: CombatantState, mods: VulnerabilityMods) {
        self.modify_bludgeon_vulnerability(mods.bludgeon);
        self.modify_magic_vulnerability(mods.magic);
        self.modify_pierce_vulnerability(mods.pierce);
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
            DamageType::Bludgeon => (*self.bludgeon_resistance, *self.bludgeon_vulnerability),
            DamageType::Magic => (*self.magic_resistance, *self.magic_vulnerability),
            DamageType::Pierce => (*self.pierce_resistance, *self.pierce_vulnerability),
        };
        let resistance: i32 = increase_resistance(*self.block, resistance).into();
        let vulnerability: i32 = vulnerability.into();
        (100 + vulnerability - resistance - vulnerability * resistance / 100).saturating_into()
    }

    fn cap_health(ref self: CombatantState) {
        self.health = min(self.max_health(), self.health);
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

    fn increase_block(ref self: CombatantState, block: u8) {
        self.block = increase_resistance(self.block, block);
    }

    fn apply_affect(
        ref self: CombatantState,
        affect: Affect,
        attacker_state: @CombatantState,
        ref randomness: Randomness,
    ) -> AffectResult {
        match affect {
            Affect::None => AffectResult::None,
            Affect::Strength(amount) => {
                self.modify_strength(amount);
                AffectResult::Applied
            },
            Affect::Vitality(amount) => {
                self.modify_vitality(amount);
                AffectResult::Applied
            },
            Affect::Dexterity(amount) => {
                self.modify_dexterity(amount);
                AffectResult::Applied
            },
            Affect::Luck(amount) => {
                self.modify_luck(amount);
                AffectResult::Applied
            },
            Affect::Abilities(mods) => {
                self.modify_abilities(mods);
                AffectResult::Applied
            },
            Affect::BludgeonResistance(amount) => {
                self.modify_bludgeon_resistance(amount);
                AffectResult::Applied
            },
            Affect::MagicResistance(amount) => {
                self.modify_magic_resistance(amount);
                AffectResult::Applied
            },
            Affect::PierceResistance(amount) => {
                self.modify_pierce_resistance(amount);
                AffectResult::Applied
            },
            Affect::Resistances(mods) => {
                self.modify_resistances(mods);
                AffectResult::Applied
            },
            Affect::BludgeonVulnerability(amount) => {
                self.modify_bludgeon_vulnerability(amount);
                AffectResult::Applied
            },
            Affect::MagicVulnerability(amount) => {
                self.modify_magic_vulnerability(amount);
                AffectResult::Applied
            },
            Affect::PierceVulnerability(amount) => {
                self.modify_pierce_vulnerability(amount);
                AffectResult::Applied
            },
            Affect::Vulnerabilities(mods) => {
                self.modify_vulnerabilities(mods);
                AffectResult::Applied
            },
            Affect::Damage(damage) => {
                AffectResult::Damage(self.apply_damage(damage, attacker_state, ref randomness))
            },
            Affect::Stun(stun) => {
                self.increase_stun(stun);
                AffectResult::Applied
            },
            Affect::Health(health) => {
                self.modify_health(health);
                AffectResult::Applied
            },
            Affect::Block(block) => {
                self.increase_block(block);
                AffectResult::Applied
            },
        }
    }
}

