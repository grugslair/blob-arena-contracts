use starknet::ContractAddress;

#[starknet::interface]
pub trait IArcade<TState> {
    fn start(
        ref self: TState,
        collection_address: ContractAddress,
        token_id: u256,
        attack_slots: Array<Array<felt252>>,
    ) -> felt252;
    fn attack(ref self: TState, attempt_id: felt252, attack_id: felt252);
    fn respawn(ref self: TState, attempt_id: felt252);
    fn forfeit(ref self: TState, attempt_id: felt252);
}
#[starknet::interface]
pub trait IArcadeSetup<TState> {
    fn energy_cost(self: @TState) -> u64;
    fn credit_cost(self: @TState) -> u128;
    fn max_respawns(self: @TState) -> u32;
    fn time_limit(self: @TState) -> u64;
    fn health_regen_permille(self: @TState) -> u32;
    fn credit_address(self: @TState) -> ContractAddress;

    fn set_max_respawns(ref self: TState, max_respawns: u32);
    fn set_time_limit(ref self: TState, time_limit: u64);
    fn set_health_regen_permille(ref self: TState, health_regen_permille: u32);
    fn set_credit_address(ref self: TState, contract_address: ContractAddress);
    fn set_cost(ref self: TState, energy: u64, credit: u128);
}
