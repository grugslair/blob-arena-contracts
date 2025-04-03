use starknet::ContractAddress;
use dojo::{world::WorldStorage, event::EventStorage};
use achievement::types::task::Task;
use achievement::events::creation::TrophyCreation;
use achievement::events::progress::TrophyProgression;
use crate::world::WorldTrait;

const ACHIEVEMENTS_NAMESPACE_HASH: felt252 = bytearray_hash!("achievements");

fn get_achievements() -> Span<TrophyCreation> {
    [].span()
}

#[generate_trait]
impl AchievementImpl<S, +WorldTrait<S>, +Drop<S>> of AchievementTrait<S> {
    fn create_achievements(ref self: S) {
        let mut storage = self.storage(ACHIEVEMENTS_NAMESPACE_HASH);
        for achievement in get_achievements() {
            storage.emit_event(achievement);
        };
    }

    fn progress_achievement(
        ref self: S, player_id: ContractAddress, task_id: felt252, count: u32, time: u64,
    ) {
        let mut storage = self.storage(ACHIEVEMENTS_NAMESPACE_HASH);
        storage
            .emit_event(@TrophyProgression { player_id: player_id.into(), task_id, count, time });
    }
}
