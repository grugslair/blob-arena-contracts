use ba_loadout::ability::{Abilities, AbilitiesTrait, AbilityTypes, DAbilities};
use ba_loadout::attack::types::Damage;
use ba_utils::{Randomness, RandomnessTrait};
use core::cmp::min;
use core::num::traits::{SaturatingAdd, SaturatingSub, Zero};
use sai_core_utils::SaturatingInto;
use sai_packing::shifts::*;
use sai_packing::{MaskDowncast, ShiftCast};
use starknet::storage::StorageNodeDeref;
use starknet::storage_access::StorePacking;
use crate::calculations::{
    apply_luck_modifier, damage_calculation, did_critical, get_new_stun_chance,
};
use crate::result::DamageResult;

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
            + ShiftCast::cast::<SHIFT_12B>(value.health)
            + ShiftCast::cast::<SHIFT_13B>(value.stun_chance)
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


impl AbilitiesIntoCombatantState of Into<Abilities, CombatantState> {
    fn into(self: Abilities) -> CombatantState {
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
            health: self.max_health(),
            stun_chance: 0,
            block: 0,
        }
    }
}

#[generate_trait]
pub impl CombatantStateImpl of CombatantStateTrait {
    fn limit_buffs(ref self: CombatantState) {
        self.abilities.limit();
    }

    fn apply_buffs(ref self: CombatantState, buffs: DAbilities) -> DAbilities {
        let change = self.abilities.apply_buffs(buffs);
        self.cap_health();
        change
    }

    fn apply_damage(
        ref self: CombatantState,
        damage: Damage,
        attacker_abilities: @Abilities,
        ref randomness: Randomness,
    ) -> DamageResult {
        let critical = did_critical(damage.critical, *attacker_abilities.luck, ref randomness);
        let mut damage = damage_calculation(damage.power, *attacker_abilities.strength, critical);
        if self.block.is_non_zero() {
            damage -= (damage * self.block.into()) / 100;
        }
        self.health = self.health.saturating_sub(damage);
        DamageResult { damage, critical }
    }

    fn modify_health(ref self: CombatantState, health: i16) -> i16 {
        let starting_health: i16 = self.health.try_into().unwrap();
        self
            .health =
                min(
                    self.max_health(),
                    self.health.try_into().unwrap().saturating_add(health).saturating_into(),
                );
        self.health.try_into().unwrap() - starting_health
    }

    fn apply_buff(ref self: CombatantState, stat: AbilityTypes, amount: i16) -> i16 {
        let result = self.abilities.apply_buff(stat, amount);
        if stat == AbilityTypes::Vitality {
            self.cap_health();
        }
        result
    }

    fn apply_strength_buff(ref self: CombatantState, amount: i16) -> i16 {
        self.abilities.apply_strength_buff(amount)
    }

    fn apply_vitality_buff(ref self: CombatantState, amount: i16) -> i16 {
        let result = self.abilities.apply_vitality_buff(amount);
        self.cap_health();
        result
    }

    fn apply_dexterity_buff(ref self: CombatantState, amount: i16) -> i16 {
        self.abilities.apply_dexterity_buff(amount)
    }

    fn apply_luck_buff(ref self: CombatantState, amount: i16) -> i16 {
        self.abilities.apply_luck_buff(amount)
    }

    fn cap_health(ref self: CombatantState) {
        self.health = min(self.max_health(), self.health);
    }

    fn max_health(self: @CombatantState) -> u16 {
        self.abilities.max_health()
    }

    fn max_health_permille(self: @CombatantState, permille: u16) -> u16 {
        self.abilities.max_health_permille(permille)
    }


    fn run_stun(ref self: CombatantState, ref randomness: Randomness) -> bool {
        let stun_chance: u8 = apply_luck_modifier(self.stun_chance, 100 - self.abilities.luck);
        self.stun_chance = 0;
        randomness.get(255) < stun_chance
    }

    fn apply_stun(ref self: CombatantState, stun: u8) {
        self.stun_chance = get_new_stun_chance(self.stun_chance, stun)
    }

    fn apply_block(ref self: CombatantState, block: u8) {
        self.block = block;
    }
}

