use starknet::{ContractAddress, get_block_timestamp};
use dojo::{world::WorldStorage, event::EventStorage};
use achievement::types::task::Task;
use achievement::events::creation::TrophyCreation;
use achievement::events::progress::TrophyProgression;
use crate::world::WorldTrait;

const ACHIEVEMENTS_NAMESPACE_HASH: felt252 = bytearray_hash!("achievements");

#[derive(Drop, Serde)]
struct TaskInput {
    id: TaskId,
    total: u32,
    description: ByteArray,
}

#[derive(Drop, Serde)]
struct TrophyCreationInput {
    id: felt252,
    hidden: bool,
    index: u8,
    points: u16,
    start: u64,
    end: u64,
    group: felt252,
    icon: felt252,
    title: felt252,
    description: ByteArray,
    tasks: Array<TaskInput>,
    data: ByteArray,
}

impl TaskInputIntoTask of Into<TaskInput, Task> {
    fn into(self: TaskInput) -> Task {
        Task { id: self.id.into(), total: self.total, description: self.description }
    }
}

impl CreationInputIntoTrophyCreation of Into<TrophyCreationInput, TrophyCreation> {
    fn into(self: TrophyCreationInput) -> TrophyCreation {
        let mut tasks = ArrayTrait::<Task>::new();
        for task in self.tasks {
            tasks.append(task.into());
        };
        TrophyCreation {
            id: self.id,
            hidden: self.hidden,
            index: self.index,
            points: self.points,
            start: self.start,
            end: self.end,
            group: self.group,
            icon: self.icon,
            title: self.title,
            description: self.description,
            tasks: tasks.span(),
            data: self.data,
        }
    }
}

#[derive(Drop, Serde, Copy, PartialEq)]
enum TaskId {
    PvpBattleVictories,
    ArcadeBattleVictories,
    ArcadeTotalDamage,
    PvpUniqueOpponent,
    ArcadeConsecutiveVictories,
    CriticalHits,
    PvpUniqueMoves,
    ArcadeUniqueMoves,
    ArcadeStarted,
    ClassicArcadeCompletion,
    AmmaArcadeCompletion,
    ArcadeCompletionNoRespawn,
    PvpWagerWon,
}

impl TaskIdIntoFelt252 of Into<TaskId, felt252> {
    fn into(self: TaskId) -> felt252 {
        match self {
            TaskId::PvpBattleVictories => 'pvp_battle_victories',
            TaskId::ArcadeBattleVictories => 'arcade_battle_victories',
            TaskId::ArcadeTotalDamage => 'arcade_total_damage',
            TaskId::PvpUniqueOpponent => 'pvp_unique_opponent',
            TaskId::ArcadeConsecutiveVictories => 'arcade_consecutive_victories',
            TaskId::CriticalHits => 'critical_hits',
            TaskId::PvpUniqueMoves => 'pvp_unique_moves',
            TaskId::ArcadeUniqueMoves => 'arcade_unique_moves',
            TaskId::ArcadeStarted => 'arcade_started',
            TaskId::ClassicArcadeCompletion => 'classic_arcade_completion',
            TaskId::AmmaArcadeCompletion => 'amma_arcade_completion',
            TaskId::ArcadeCompletionNoRespawn => 'arcade_completion_no_respawn',
            TaskId::PvpWagerWon => 'pvp_wager_won',
        }
    }
}

#[generate_trait]
impl AchievementsEventsImpl of AchievementsEventsTrait {
    fn emit_progress_achievement(
        ref self: WorldStorage, player_id: felt252, task: TaskId, count: u32, time: u64,
    ) {
        self
            .emit_event(
                @TrophyProgression { player_id: player_id, task_id: task.into(), count, time },
            );
    }
}

#[generate_trait]
impl AchievementImpl<S, +WorldTrait<S>, +Drop<S>> of Achievements<S> {
    fn create_achievements(ref self: S, achievements: Array<TrophyCreationInput>) {
        let mut storage = self.storage(ACHIEVEMENTS_NAMESPACE_HASH);
        for achievement_input in achievements {
            let achievement: TrophyCreation = achievement_input.into();
            storage.emit_event(@achievement);
        };
    }

    fn _progress_achievement(
        ref self: S, player_id: ContractAddress, task: TaskId, count: u32, time: u64,
    ) {
        let mut storage = self.storage(ACHIEVEMENTS_NAMESPACE_HASH);
        storage.emit_progress_achievement(player_id.into(), task, count, time);
    }

    fn progress_achievement(
        ref self: S, player_id: ContractAddress, task: TaskId, count: u32, time: u64,
    ) {
        if count > 0 {
            self._progress_achievement(player_id, task, count, time);
        }
    }

    fn progress_achievements(
        ref self: S, player_id: ContractAddress, task_and_counts: Array<(TaskId, u32)>, time: u64,
    ) {
        let mut storage = self.storage(ACHIEVEMENTS_NAMESPACE_HASH);
        let player_felt: felt252 = player_id.into();
        for (task, count) in task_and_counts {
            if count > 0 {
                storage.emit_progress_achievement(player_felt, task, count, time);
            }
        };
    }

    fn progress_achievements_now(
        ref self: S, player_id: ContractAddress, task_and_counts: Array<(TaskId, u32)>,
    ) {
        self.progress_achievements(player_id, task_and_counts, get_block_timestamp());
    }


    fn progress_achievement_now(ref self: S, player_id: ContractAddress, task: TaskId, count: u32) {
        self.progress_achievement(player_id, task, count, get_block_timestamp());
    }

    fn increment_achievement(ref self: S, player_id: ContractAddress, task: TaskId, time: u64) {
        self._progress_achievement(player_id, task, 1, time);
    }

    fn increment_achievement_now(ref self: S, player_id: ContractAddress, task: TaskId) {
        self.increment_achievement(player_id, task, get_block_timestamp());
    }

    fn increment_achievements(
        ref self: S, player_id: ContractAddress, task_and_counts: Array<(TaskId, u32)>, time: u64,
    ) {
        let mut storage = self.storage(ACHIEVEMENTS_NAMESPACE_HASH);
        let player_felt: felt252 = player_id.into();
        for (task, count) in task_and_counts {
            if count > 0 {
                storage.emit_progress_achievement(player_felt, task, count + 1, time);
            }
        };
    }

    fn increment_achievements_now(
        ref self: S, player_id: ContractAddress, task_and_counts: Array<(TaskId, u32)>,
    ) {
        self.increment_achievements(player_id, task_and_counts, get_block_timestamp());
    }
}
