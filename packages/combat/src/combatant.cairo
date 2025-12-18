use ba_loadout::action::effect::{Abilities, Modifiers};
use ba_loadout::action::{Affect, Damage, DamageType, HealthMod, HealthModType};
use ba_loadout::attributes::{
    Attributes, MAX_ABILITY_VALUE, MODIFIER_SCALE_U32_U32, MODIFIER_SCALE_U32_U64,
    STUN_MODIFIER_SCALE, combine_4_modifiers_u32, combine_modifiers_u32, combine_stun_modifiers,
};
use ba_utils::{CapInto, IntoRange, Randomness, RandomnessTrait};
use core::cmp::{max, min};
use core::num::traits::{SaturatingAdd, SaturatingSub, WideMul};
use sai_core_utils::SaturatingInto;
use sai_packing::masks::{*, MASK_7b_U8};
use sai_packing::shifts::*;
use sai_packing::{MaskDowncast, ShiftCast};
use starknet::storage::StorageNodeDeref;
use starknet::storage_access::StorePacking;
use crate::calculations::{damage_calculation, did_critical, get_new_stun_chance};
use crate::result::{AbilitiesResult, AbilitiesTempResult, AffectResult, DamageResult};

pub const BASE_HEALTH: u16 = 100;
pub const BASE_HEALTH_I32: i32 = BASE_HEALTH.into();

#[derive(Drop, Copy, Serde, Schema, Introspect, Default)]
pub struct CombatantState {
    pub strength: u16,
    pub vitality: u16,
    pub dexterity: u16,
    pub luck: u16,
    pub stun_modifier: u16,
    pub damage_modifier: u32,
    pub bludgeon_modifier: u32,
    pub magic_modifier: u32,
    pub pierce_modifier: u32,
    pub stun_chance: u8,
    pub health: u16,
    /// temp values
    pub strength_temp: i16,
    pub vitality_temp: i16,
    pub dexterity_temp: i16,
    pub luck_temp: i16,
    pub stun_modifier_temp: u16,
    pub damage_modifier_temp: u32,
    pub bludgeon_modifier_temp: u32,
    pub magic_modifier_temp: u32,
    pub pierce_modifier_temp: u32,
}

impl UAbilityStorePacking of StorePacking<CombatantState, felt252> {
    fn pack(value: CombatantState) -> felt252 {
        value.strength.into()
            + SHIFT_14b_FELT252 * value.vitality.into()
            + SHIFT_28b_FELT252 * value.dexterity.into()
            + SHIFT_42b_FELT252 * value.luck.into()
            + SHIFT_56b_FELT252 * value.stun_modifier.into()
            + SHIFT_70b_FELT252 * value.bludgeon_modifier.into()
            + SHIFT_101b_FELT252 * value.magic_modifier.into()
            + SHIFT_132b_FELT252 * value.pierce_modifier.into()
            + SHIFT_163b_FELT252 * value.damage_modifier.into()
            + SHIFT_194b_FELT252 * value.stun_chance.into()
            + SHIFT_201b_FELT252 * value.health.into()
    }

    fn unpack(value: felt252) -> CombatantState {
        let value: u256 = value.into();
        let u256 { low, high } = value;
        CombatantState {
            strength: MaskDowncast::cast(low) & MASK_14b_U16,
            vitality: ShiftCast::const_unpack::<SHIFT_14b>(low) & MASK_14b_U16,
            dexterity: ShiftCast::const_unpack::<SHIFT_28b>(low) & MASK_14b_U16,
            luck: ShiftCast::const_unpack::<SHIFT_42b>(low) & MASK_14b_U16,
            stun_modifier: ShiftCast::const_unpack::<SHIFT_56b>(low) & MASK_14b_U16,
            bludgeon_modifier: ShiftCast::const_unpack::<SHIFT_70b>(low) & MASK_31b_U32,
            magic_modifier: ShiftCast::const_unpack::<SHIFT_101b>(value) & MASK_31b_U32,
            pierce_modifier: ShiftCast::const_unpack::<SHIFT_4b>(high) & MASK_31b_U32,
            damage_modifier: ShiftCast::const_unpack::<SHIFT_35b>(high) & MASK_31b_U32,
            stun_chance: ShiftCast::const_unpack::<SHIFT_66b>(high) & MASK_7b_U8,
            health: ShiftCast::const_unpack::<SHIFT_73b>(high),
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


pub fn get_starting_health(vitality: u16) -> u16 {
    BASE_HEALTH + vitality
}

pub fn get_max_health_temp(vitality: u16, temp: i16) -> u16 {
    (BASE_HEALTH_I32 + vitality.into() + temp.into()).saturating_into()
}

pub fn get_starting_health_percent(vitality: u16, percent: u8) -> u16 {
    (get_starting_health(vitality).wide_mul(percent.into()) / 100_u32).saturating_into()
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
            health: get_starting_health(self.vitality),
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
        }
    }
}

fn add_abilities(ref current: u16, modifier: i16, cap: Option<u16>) {
    current = (Into::<_, i32>::into(current) + modifier.into())
        .cap_into(cap.unwrap_or(MAX_ABILITY_VALUE));
}

fn add_abilities_temp(ref current: i16, modifier: i16, cap: Option<u16>) {
    let cap: i16 = cap.unwrap_or(MAX_ABILITY_VALUE).saturating_into();
    current = (Into::<_, i32>::into(current) + modifier.into()).into_range(-cap, cap);
}

fn add_modifiers(ref current: u32, modifier: u32) {
    current = combine_modifiers_u32(current, modifier);
}

fn combine_ability(value: u16, temp: i16, cap: Option<u16>) -> u16 {
    let val: u16 = (value.saturating_into() + temp).saturating_into();
    min(val, cap.unwrap_or(MAX_ABILITY_VALUE))
}


#[generate_trait]
pub impl CombatantStateImpl of CombatantStateTrait {
    fn cap_health(ref self: CombatantState) {
        self.health = min(self.health, self.max_health());
    }

    fn strength(self: @CombatantState, cap: Option<u16>) -> u16 {
        combine_ability(*self.strength, *self.strength_temp, cap)
    }

    fn vitality(self: @CombatantState, cap: Option<u16>) -> u16 {
        combine_ability(*self.vitality, *self.vitality_temp, cap)
    }

    fn dexterity(self: @CombatantState, cap: Option<u16>) -> u16 {
        combine_ability(*self.dexterity, *self.dexterity_temp, cap)
    }

    fn luck(self: @CombatantState, cap: Option<u16>) -> u16 {
        combine_ability(*self.luck, *self.luck_temp, cap)
    }

    fn stun_modifier(self: @CombatantState) -> u16 {
        combine_stun_modifiers(*self.stun_modifier, *self.stun_modifier_temp)
    }


    fn add_abilities(
        ref self: CombatantState, attrs: Abilities, cap: Option<u16>,
    ) -> AbilitiesResult {
        add_abilities(ref self.strength, attrs.strength, cap);
        add_abilities(ref self.vitality, attrs.vitality, cap);
        add_abilities(ref self.dexterity, attrs.dexterity, cap);
        add_abilities(ref self.luck, attrs.luck, cap);
        self.cap_health();
        AbilitiesResult {
            strength: self.strength,
            vitality: self.vitality,
            dexterity: self.dexterity,
            luck: self.luck,
            health: self.health,
        }
    }

    fn add_abilities_temp(
        ref self: CombatantState, attrs: Abilities, cap: Option<u16>,
    ) -> AbilitiesTempResult {
        add_abilities_temp(ref self.strength_temp, attrs.strength, cap);
        add_abilities_temp(ref self.vitality_temp, attrs.vitality, cap);
        add_abilities_temp(ref self.dexterity_temp, attrs.dexterity, cap);
        add_abilities_temp(ref self.luck_temp, attrs.luck, cap);
        self.cap_health();
        AbilitiesTempResult {
            strength: self.strength_temp,
            vitality: self.vitality_temp,
            dexterity: self.dexterity_temp,
            luck: self.luck_temp,
            health: self.health,
        }
    }

    fn add_modifiers(ref self: CombatantState, modifiers: Modifiers) -> Modifiers {
        add_modifiers(ref self.damage_modifier, modifiers.all_types);
        add_modifiers(ref self.bludgeon_modifier, modifiers.bludgeon);
        add_modifiers(ref self.magic_modifier, modifiers.magic);
        add_modifiers(ref self.pierce_modifier, modifiers.pierce);
        Modifiers {
            all_types: self.damage_modifier,
            bludgeon: self.bludgeon_modifier,
            magic: self.magic_modifier,
            pierce: self.pierce_modifier,
        }
    }

    fn add_modifiers_temp(ref self: CombatantState, modifiers: Modifiers) -> Modifiers {
        add_modifiers(ref self.damage_modifier_temp, modifiers.all_types);
        add_modifiers(ref self.bludgeon_modifier_temp, modifiers.bludgeon);
        add_modifiers(ref self.magic_modifier_temp, modifiers.magic);
        add_modifiers(ref self.pierce_modifier_temp, modifiers.pierce);
        Modifiers {
            all_types: self.damage_modifier_temp,
            bludgeon: self.bludgeon_modifier_temp,
            magic: self.magic_modifier_temp,
            pierce: self.pierce_modifier_temp,
        }
    }

    fn add_stun_modifier(ref self: CombatantState, modifier: u16) -> u16 {
        self.stun_modifier = combine_stun_modifiers(self.stun_modifier, modifier);
        self.stun_modifier
    }

    fn add_stun_modifier_temp(ref self: CombatantState, modifier: u16) -> u16 {
        self.stun_modifier_temp = combine_stun_modifiers(self.stun_modifier_temp, modifier);
        self.stun_modifier_temp
    }

    fn add_health(ref self: CombatantState, amount: u16) {
        self.health = min(self.health.saturating_add(amount), self.max_health());
    }

    fn subtract_health(ref self: CombatantState, amount: u16) {
        self.health = self.health.saturating_sub(amount);
    }

    fn set_health(ref self: CombatantState, health: u16) {
        self.health = min(health, self.max_health());
    }

    fn floor_health(ref self: CombatantState, health: u16) {
        self.health = min(max(self.health, health), self.max_health());
    }

    fn ceil_health(ref self: CombatantState, health: u16) {
        self.health = min(self.health, health);
    }

    fn apply_damage(
        ref self: CombatantState,
        damage: Damage,
        actor_state: @CombatantState,
        ability_cap: Option<u16>,
        ref randomness: Randomness,
    ) -> DamageResult {
        let critical = did_critical(damage.critical, actor_state.luck(ability_cap), ref randomness);
        let mut hp = damage_calculation(damage.power, actor_state.strength(ability_cap), critical);
        let affinity = self.combine_damage_modifier(damage.damage_type);
        if affinity != MODIFIER_SCALE_U32_U32 {
            hp = (affinity.wide_mul(hp.into()) / MODIFIER_SCALE_U32_U64).saturating_into();
        }
        self.health = self.health.saturating_sub(hp);
        DamageResult { hp, critical }
    }

    fn set_and_regen_health(ref self: CombatantState, health: u16, amount: u16) {
        self.health = health;
        self.health = min(self.health.saturating_add(amount), self.max_health());
    }


    fn modify_health(ref self: CombatantState, modification: HealthMod<u16>) -> u16 {
        match modification.mod_type {
            HealthModType::Add => self.add_health(modification.value),
            HealthModType::Subtract => self.subtract_health(modification.value),
            HealthModType::Set => self.set_health(modification.value),
            HealthModType::Floor => self.floor_health(modification.value),
            HealthModType::Ceil => self.ceil_health(modification.value),
        }
        self.health
    }

    fn modify_health_percent(ref self: CombatantState, modification: HealthMod<u8>) -> u16 {
        let value: u16 = self.percentage_of_max_health(modification.value);
        match modification.mod_type {
            HealthModType::Add => self.add_health(value),
            HealthModType::Subtract => self.subtract_health(value),
            HealthModType::Set => self.set_health(value),
            HealthModType::Floor => self.floor_health(value),
            HealthModType::Ceil => self.ceil_health(value),
        }
        self.health
    }

    fn combine_damage_modifier(self: @CombatantState, damage_type: DamageType) -> u32 {
        let (perm, temp) = match damage_type {
            DamageType::None => {
                return combine_modifiers_u32(*self.damage_modifier, *self.damage_modifier_temp);
            },
            DamageType::Bludgeon => (*self.bludgeon_modifier, *self.bludgeon_modifier_temp),
            DamageType::Magic => (*self.magic_modifier, *self.magic_modifier_temp),
            DamageType::Pierce => (*self.pierce_modifier, *self.pierce_modifier_temp),
        };
        combine_4_modifiers_u32(perm, temp, *self.damage_modifier, *self.damage_modifier_temp)
    }

    fn max_health(self: @CombatantState) -> u16 {
        get_max_health_temp(*self.vitality, *self.vitality_temp)
    }

    fn percentage_of_max_health(self: @CombatantState, percent: u8) -> u16 {
        (self.max_health().wide_mul(percent.into()) / 100).saturating_into()
    }
    fn run_stun(ref self: CombatantState, ref randomness: Randomness) -> bool {
        let stun_chance: u8 = (self.stun_modifier().wide_mul(self.stun_chance.into())
            / STUN_MODIFIER_SCALE)
            .saturating_into();
        self.stun_chance = 0;
        randomness.get(100) < stun_chance
    }

    fn increase_stun(ref self: CombatantState, stun: u8) -> u8 {
        self.stun_chance = get_new_stun_chance(self.stun_chance, stun);
        self.stun_chance
    }

    fn apply_affect(
        ref self: CombatantState,
        affect: Affect,
        actor_state: @CombatantState,
        ability_cap: Option<u16>,
        ref randomness: Randomness,
    ) -> AffectResult {
        match affect {
            Affect::Health(modification) => AffectResult::Health(self.modify_health(modification)),
            Affect::HealthMaxPercent(modification) => AffectResult::Health(
                self.modify_health_percent(modification),
            ),
            Affect::Stun(value) => AffectResult::Stun(self.increase_stun(value)),
            Affect::StunModifier(value) => AffectResult::StunModifier(
                self.add_stun_modifier(value),
            ),
            Affect::StunModifierTemp(value) => AffectResult::StunModifierTemp(
                self.add_stun_modifier_temp(value),
            ),
            Affect::Abilities(attrs) => AffectResult::Abilities(
                self.add_abilities(attrs, ability_cap),
            ),
            Affect::AbilitiesTemp(attrs) => AffectResult::AbilitiesTemp(
                self.add_abilities_temp(attrs, ability_cap),
            ),
            Affect::DamageModifiers(modifiers) => AffectResult::DamageModifiers(
                self.add_modifiers(modifiers),
            ),
            Affect::DamageModifiersTemp(modifiers) => AffectResult::DamageModifiersTemp(
                self.add_modifiers_temp(modifiers),
            ),
            Affect::Damage(effect) => AffectResult::Damage(
                self.apply_damage(effect, actor_state, ability_cap, ref randomness),
            ),
        }
    }
}

