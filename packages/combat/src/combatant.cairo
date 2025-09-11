use ba_loadout::ability::{Abilities, AbilitiesTrait, AbilityTypes, DAbilities};
use ba_loadout::attack::types::Damage;
use ba_utils::{Randomness, RandomnessTrait};
use core::cmp::min;
use core::num::traits::{SaturatingAdd, SaturatingSub, Zero};
use sai_core_utils::SaturatingInto;
use sai_packing::MaskDowncast;
use sai_packing::byte::{SHIFT_10B, SHIFT_8B, ShiftCast};
use starknet::storage::StorageNodeDeref;
use starknet::storage_access::StorePacking;
use crate::calculations::{
    apply_luck_modifier, damage_calculation, did_critical, get_new_stun_chance,
};
use crate::result::DamageResult;

#[derive(Drop, Copy, Serde, Schema, Introspect, Default)]
pub struct CombatantState {
    pub health: u16,
    pub stun_chance: u8,
    pub abilities: Abilities,
    pub block: u8,
}


impl UAbilityStorePacking of StorePacking<CombatantState, felt252> {
    fn pack(value: CombatantState) -> felt252 {
        let value: u128 = StorePacking::pack(value.abilities).into()
            + ShiftCast::cast::<SHIFT_8B>(value.health)
            + ShiftCast::cast::<SHIFT_10B>(value.stun_chance);
        value.into()
    }

    fn unpack(value: felt252) -> CombatantState {
        let value: u128 = value.try_into().unwrap();

        let health: u16 = ShiftCast::unpack::<SHIFT_8B>(value);
        let stun_chance = ShiftCast::unpack::<SHIFT_10B>(value);
        let abilities = StorePacking::unpack(MaskDowncast::cast(value));
        CombatantState { health, stun_chance, abilities, block: 0 }
    }
}


impl AbilitiesIntoCombatantState of Into<Abilities, CombatantState> {
    fn into(self: Abilities) -> CombatantState {
        CombatantState { health: self.max_health(), stun_chance: 0, abilities: self, block: 0 }
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

