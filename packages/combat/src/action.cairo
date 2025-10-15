#[derive(Drop, Serde, Copy, PartialEq, Default, starknet::Store)]
pub enum Action {
    #[default]
    None,
    Attack: felt252,
    Orb: felt252,
}
