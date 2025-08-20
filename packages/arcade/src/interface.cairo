use starknet::ContractAddress;

#[starknet::interface]
trait IArcade<TState> {
    fn start(
        ref self: TState,
        collection_address: ContractAddress,
        token_id: u256,
        attack_slots: Array<Array<felt252>>,
    ) -> felt252;
    fn attack(ref self: TState, attempt_id: felt252, attack_id: felt252);
    fn respawn(ref self: TState, attempt_id: felt252);
    fn forfeit(ref self: TState, attempt_id: felt252);

    fn fuel_cost(self: @TState) -> u64;
    fn credits_cost(self: @TState) -> u128;
    fn max_respawns(self: @TState) -> u32;
    fn time_limit(self: @TState) -> u64;
    fn health_regen_permille(self: @TState) -> u32;
    fn fuel_contract(self: @TState) -> ContractAddress;

    fn set_max_respawns(ref self: TState, max_respawns: u32);
    fn set_time_limit(ref self: TState, time_limit: u64);
    fn set_health_regen_permille(ref self: TState, health_regen_permille: u32);
    fn set_fuel_contract(ref self: TState, fuel_contract: ContractAddress);
    fn set_cost(ref self: TState, fuel_cost: u64, credits_cost: u128);
}
