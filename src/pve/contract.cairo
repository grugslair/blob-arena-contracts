#[dojo::interface]
trait IPVE<TContractState> {
    fn new(ref self: TContractState, opponent_token: felt252) -> felt252;
    fn attack(ref self: TContractState, game_id: felt252, attack: felt252);
}

#[dojo::contract]
mod pve_actions {
    impl IPVEImpl of IPVE<ContractState> {
        fn new(ref self: ContractState, opponent_token: felt252) -> felt252 {}
        fn attack(ref self: ContractState, game_id: felt252, attack: felt252) {}
    }
}
