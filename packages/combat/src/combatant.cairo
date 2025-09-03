use ba_loadout::ability::{
    Abilities, AbilitiesTrait, AbilityTypes, DAbilities, U32_MASK_U128, U32_SHIFT_1,
};
use ba_loadout::attack::types::Damage;
use ba_utils::SeedProbability;
use core::cmp::min;
use core::num::traits::{SaturatingAdd, SaturatingSub, Zero};
use sai_core_utils::SaturatingInto;
use starknet::storage::StorageNodeDeref;
use starknet::storage_access::StorePacking;
use crate::calculations::{
    apply_luck_modifier, damage_calculation, did_critical, get_new_stun_chance,
};
use crate::result::DamageResult;


#[derive(Drop, Copy, Serde, Schema, Introspect, Default)]
pub struct CombatantState {
    pub health: u32,
    pub stun_chance: u8,
    pub abilities: Abilities,
    pub block: u8,
}


impl UAbilityStorePacking of StorePacking<CombatantState, felt252> {
    fn pack(value: CombatantState) -> felt252 {
        let high = value.health.into() + value.stun_chance.into() * U32_SHIFT_1;
        let low = StorePacking::pack(value.abilities);
        u256 { high, low }.try_into().unwrap()
    }

    fn unpack(value: felt252) -> CombatantState {
        let u256 { high, low } = value.into();
        let health = (high & U32_MASK_U128).try_into().unwrap();
        let stun_chance = ((high / U32_SHIFT_1) & U32_MASK_U128).try_into().unwrap();
        let abilities = StorePacking::unpack(low);
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
        ref self: CombatantState, damage: Damage, attacker_abilities: @Abilities, ref seed: u128,
    ) -> DamageResult {
        let critical = did_critical(damage.critical, *attacker_abilities.luck, ref seed);
        let mut damage = damage_calculation(damage.power, *attacker_abilities.strength, critical);
        if self.block.is_non_zero() {
            damage -= (damage * self.block.into()) / 100;
        }
        self.health = self.health.saturating_sub(damage);
        DamageResult { damage, critical }
    }

    fn modify_health(ref self: CombatantState, health: i32) -> i32 {
        let starting_health: i32 = self.health.try_into().unwrap();
        self
            .health =
                min(
                    self.max_health(),
                    self.health.try_into().unwrap().saturating_add(health).saturating_into(),
                );
        self.health.try_into().unwrap() - starting_health
    }

    fn apply_buff(ref self: CombatantState, stat: AbilityTypes, amount: i32) -> i32 {
        let result = self.abilities.apply_buff(stat, amount);
        if stat == AbilityTypes::Vitality {
            self.cap_health();
        }
        result
    }

    fn cap_health(ref self: CombatantState) {
        self.health = min(self.max_health(), self.health);
    }

    fn max_health(self: @CombatantState) -> u32 {
        self.abilities.max_health()
    }

    fn max_health_permille(self: @CombatantState, permille: u32) -> u32 {
        self.abilities.max_health_permille(permille)
    }


    fn run_stun(ref self: CombatantState, ref seed: u128) -> bool {
        let stun_chance: u8 = apply_luck_modifier(self.stun_chance, 100 - self.abilities.luck);
        self.stun_chance = 0;
        seed.get_outcome(255, stun_chance)
    }

    fn apply_stun(ref self: CombatantState, stun: u8) {
        self.stun_chance = get_new_stun_chance(self.stun_chance, stun)
    }

    fn apply_block(ref self: CombatantState, block: u8) {
        self.block = block;
    }
}

