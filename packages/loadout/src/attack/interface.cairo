use starknet::ContractAddress;
use crate::attack::{Attack, AttackWithName, Effect};
use super::IdTagAttack;

#[starknet::interface]
pub trait IAttack<TContractState> {
    fn attack(self: @TContractState, id: felt252) -> Attack;
    fn attacks(self: @TContractState, ids: Array<felt252>) -> Array<Attack>;
    fn speed(self: @TContractState, id: felt252) -> u32;
    fn speeds(self: @TContractState, ids: Array<felt252>) -> Array<u32>;
    fn chance(self: @TContractState, id: felt252) -> u8;
    fn chances(self: @TContractState, ids: Array<felt252>) -> Array<u8>;
    fn cooldown(self: @TContractState, id: felt252) -> u32;
    fn cooldowns(self: @TContractState, ids: Array<felt252>) -> Array<u32>;
    fn success(self: @TContractState, id: felt252) -> Array<Effect>;
    fn successes(self: @TContractState, ids: Array<felt252>) -> Array<Array<Effect>>;
    fn fail(self: @TContractState, id: felt252) -> Array<Effect>;
    fn fails(self: @TContractState, ids: Array<felt252>) -> Array<Array<Effect>>;
    fn attack_id(
        self: @TContractState,
        name: ByteArray,
        speed: u32,
        chance: u8,
        cooldown: u32,
        success: Array<Effect>,
        fail: Array<Effect>,
    ) -> felt252;
    fn attack_ids(self: @TContractState, attacks: Array<AttackWithName>) -> Array<felt252>;
    fn tag(self: @TContractState, tag: felt252) -> felt252;
}


#[starknet::interface]
pub trait IAttackAdmin<TContractState> {
    fn create_attack(
        ref self: TContractState,
        name: ByteArray,
        speed: u32,
        chance: u8,
        cooldown: u32,
        success: Array<Effect>,
        fail: Array<Effect>,
    ) -> felt252;
    fn create_attacks(ref self: TContractState, attacks: Array<AttackWithName>) -> Array<felt252>;
    fn maybe_create_attacks(
        ref self: TContractState, attacks: Array<IdTagAttack>,
    ) -> Array<felt252>;
}

pub fn maybe_create_attacks(
    contract_address: ContractAddress, attacks: Array<IdTagAttack>,
) -> Array<felt252> {
    IAttackAdminDispatcher { contract_address }.maybe_create_attacks(attacks)
}
