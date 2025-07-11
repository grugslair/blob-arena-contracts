#[starknet::interface]
trait IAbilities<TContractState> {
    fn available_attacks(self: @TContractState, token_id: felt252, data: Span<felt252>) -> Array<felt252>;
    fn stats(self: @TContractState, token_id: felt252, data: Span<felt252>) -> Stats;
}

#[starknet::interface]
trait IAttacks<TContractState> {
    fn attack(self: @TContractState, attack_id: felt252) -> Attack;
    fn attacks(self: @TContractState, attack_ids: Span<felt252>) -> Array<Attack>;
}

