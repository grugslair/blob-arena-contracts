use crate::attack::{Attack, AttackWithName, Effect};

#[starknet::interface]
pub trait IAttack<TContractState> {
    fn attack(self: @TContractState, id: felt252) -> Attack;
    fn attacks(self: @TContractState, ids: Array<felt252>) -> Array<Attack>;
    fn speed(self: @TContractState, id: felt252) -> u8;
    fn speeds(self: @TContractState, ids: Array<felt252>) -> Array<u8>;
    fn accuracy(self: @TContractState, id: felt252) -> u8;
    fn accuracies(self: @TContractState, ids: Array<felt252>) -> Array<u8>;
    fn cooldown(self: @TContractState, id: felt252) -> u8;
    fn cooldowns(self: @TContractState, ids: Array<felt252>) -> Array<u8>;
    fn hit(self: @TContractState, id: felt252) -> Array<Effect>;
    fn hits(self: @TContractState, ids: Array<felt252>) -> Array<Array<Effect>>;
    fn miss(self: @TContractState, id: felt252) -> Array<Effect>;
    fn misses(self: @TContractState, ids: Array<felt252>) -> Array<Array<Effect>>;
    fn attack_id(
        self: @TContractState,
        name: ByteArray,
        speed: u8,
        accuracy: u8,
        cooldown: u8,
        hit: Array<Effect>,
        miss: Array<Effect>,
    ) -> felt252;
    fn attack_ids(self: @TContractState, attacks: Array<AttackWithName>) -> Array<felt252>;
}


#[starknet::interface]
pub trait IAttackAdmin<TContractState> {
    fn create_attack(
        ref self: TContractState,
        name: ByteArray,
        speed: u8,
        accuracy: u8,
        cooldown: u8,
        hit: Array<Effect>,
        miss: Array<Effect>,
    ) -> felt252;
    fn create_attacks(ref self: TContractState, attacks: Array<AttackWithName>) -> Array<felt252>;
}

