use achievement::types::task::Task;
use achievement::events::creation::TrophyCreation;

const TASK_ID: felt252 = 'arcade_completion';
const GROUP_NAME: felt252 = 'Arcade Completion';

fn arcade_completion_1() -> TrophyCreation {
    let description: ByteArray = "Won 1 Arcade Challenge";
    TrophyCreation {
        id: 'arcade_completion_1',
        hidden: false,
        index: 1,
        points: 20,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: 'shield',
        title: 'Arcade Squire',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 1, description },].span(),
        data: "",
    }
}

fn arcade_completion_5() -> TrophyCreation {
    let description: ByteArray = "Won 5 Arcade Challenges";
    TrophyCreation {
        id: 'arcade_completion_5',
        hidden: false,
        index: 2,
        points: 50,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: 'shield-halved',
        title: 'Arcade Knight',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 5, description },].span(),
        data: "",
    }
}

fn arcade_completion_20() -> TrophyCreation {
    let description: ByteArray = "Won 20 Arcade Challenges";
    TrophyCreation {
        id: 'arcade_completion_20',
        hidden: false,
        index: 3,
        points: 100,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: 'shield-quartered',
        title: 'Arcade Warlord',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 20, description },].span(),
        data: "",
    }
}

fn arcade_completion_50() -> TrophyCreation {
    let description: ByteArray = "Won 50 Arcade Challenges";
    TrophyCreation {
        id: 'arcade_completion_50',
        hidden: false,
        index: 4,
        points: 200,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: 'dragon',
        title: 'Arcade Master',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 50, description },].span(),
        data: "",
    }
}
