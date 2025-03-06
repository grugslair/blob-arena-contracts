use starknet::ContractAddress;

#[starknet::interface]
trait IExperience<TState> {
    fn experience(
        ref self: TState, collection: ContractAddress, token_id: u256, player: ContractAddress,
    ) -> u128;
    fn token_experience(ref self: TState, collection: ContractAddress, token_id: u256) -> u128;
    fn collection_player_experience(
        ref self: TState, collection: ContractAddress, player: ContractAddress,
    ) -> u128;
    fn player_experience(ref self: TState, player: ContractAddress) -> u128;
    fn collection_experience(ref self: TState, collection: ContractAddress) -> u128;

    fn total_experience(ref self: TState) -> u128;
}

#[starknet::interface]
trait IExperienceMintBurn<TState> {
    fn mint_to(
        ref self: TState,
        collection: ContractAddress,
        token_id: u256,
        player: ContractAddress,
        amount: u128,
    );
    fn burn_from(
        ref self: TState,
        collection: ContractAddress,
        token_id: u256,
        player: ContractAddress,
        amount: u128,
    );
}

#[starknet::interface]
trait IExperienceAdmin<TState> {
    fn set_admin(ref self: TState, user: ContractAddress, is_admin: bool);
    fn set_writer(ref self: TState, user: ContractAddress, is_writer: bool);
    fn set_collection_cap(ref self: TState, collection: ContractAddress, cap: u128);
}
