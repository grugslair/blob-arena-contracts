use ba_utils::SeedProbability;
use crate::component::arcade_component::ComponentState;



#[generate_trait]
impl ArcadeRewardsImpl<TState> of ArcadeReward<TState>{
    fn get_round_reward(self: ComponentState<TState>, ref randomness: u128) {
        let value = randomness.get_value(20)
    }
} 