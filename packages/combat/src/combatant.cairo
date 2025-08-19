use ba_loadout::ability::{Abilities, AbilitiesTrait, AbilityTypes, DAbilities};
use ba_utils::SeedProbability;
use core::cmp::min;
use core::num::traits::SaturatingAdd;
use sai_core_utils::SaturatingInto;
use starknet::ContractAddress;
use starknet::storage::{
    Map, Mutable, StorageBase, StorageNodeDeref, StoragePathEntry, StoragePointerReadAccess,
    StoragePointerWriteAccess,
};
use crate::calculations::{apply_luck_modifier, get_new_stun_chance};

#[starknet::storage_node]
pub struct CombatantNode {
    pub combat_id: felt252,
    pub player: ContractAddress,
    pub collection_address: ContractAddress,
    pub token_id: u256,
    pub health: u32,
    pub stun_chance: u8,
    pub abilities: Abilities,
}

#[derive(Drop, Serde, Introspect)]
pub struct Combatant {
    pub combat_id: felt252,
    pub player: ContractAddress,
    pub collection_address: ContractAddress,
    pub token_id: u256,
    pub health: u32,
    pub stun_chance: u8,
    pub abilities: Abilities,
}

#[derive(Drop, Copy, Serde, Schema, starknet::Store, Introspect)]
pub struct CombatantState {
    pub health: u32,
    pub stun_chance: u8,
    pub abilities: Abilities,
}


impl AbilitiesIntoCombatantState of Into<Abilities, CombatantState> {
    fn into(self: Abilities) -> CombatantState {
        CombatantState { health: self.max_health(), stun_chance: 0, abilities: self }
    }
}

#[generate_trait]
impl CombatantNodeImpl of CombatantNodeTrait {
    fn read_abilitiese(
        self: StorageBase<Map<felt252, CombatantNode>>, id: felt252,
    ) -> CombatantState {
        let node = self.entry(id);
        CombatantState {
            health: node.health.read(),
            stun_chance: node.stun_chance.read(),
            abilities: node.abilities.read(),
        }
    }

    fn write_abilitiese(
        ref self: StorageBase<Map<felt252, Mutable<CombatantNode>>>,
        id: felt252,
        state: CombatantState,
    ) {
        let mut node = self.entry(id);
        node.health.write(state.health);
        node.stun_chance.write(state.stun_chance);
        node.abilities.write(state.abilities);
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
}

