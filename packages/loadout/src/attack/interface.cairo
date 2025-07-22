use crate::attack::{Attack, AttackInput, Effect, EffectInput};

#[starknet::interface]
trait IAttack<TContractState> {
    fn attack(self: @TContractState, attack_id: felt252) -> Attack;
    fn attacks(self: @TContractState, attack_ids: Span<felt252>) -> Array<Attack>;
    fn speed(self: @TContractState, attack_id: felt252) -> u8;
    fn speeds(self: @TContractState, attack_ids: Span<felt252>) -> Array<u8>;
    fn accuracy(self: @TContractState, attack_id: felt252) -> u8;
    fn accuracies(self: @TContractState, attack_ids: Span<felt252>) -> Array<u8>;
    fn cooldown(self: @TContractState, attack_id: felt252) -> u8;
    fn cooldowns(self: @TContractState, attack_ids: Span<felt252>) -> Array<u8>;
    fn hit(self: @TContractState, attack_id: felt252) -> Array<Effect>;
    fn hits(self: @TContractState, attack_ids: Span<felt252>) -> Array<Array<Effect>>;
    fn miss(self: @TContractState, attack_id: felt252) -> Array<Effect>;
    fn misses(self: @TContractState, attack_ids: Span<felt252>) -> Array<Array<Effect>>;
}


#[starknet::interface]
trait IAttackAdmin<TContractState> {
    fn create_attack(
        ref self: TContractState,
        name: ByteArray,
        speed: u8,
        accuracy: u8,
        cooldown: u8,
        hit: Array<EffectInput>,
        miss: Array<EffectInput>,
    ) -> felt252;

    fn create_attacks(ref self: TContractState, attacks: Array<AttackInput>) -> Array<felt252>;
}
