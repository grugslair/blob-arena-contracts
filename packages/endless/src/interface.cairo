use ba_combat::Move;

#[starknet::interface]
pub trait IEndless<TState> {
    fn create(ref self: TState);
    fn act(ref self: TState, attempt_id: u64, move: Move);
    fn respawn(ref self: TState, attempt_id: u64);
    fn claim_jackpot(ref self: TState, season: u64, place: u8);
}
