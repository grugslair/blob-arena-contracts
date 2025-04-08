use achievement::types::task::Task;
use achievement::events::creation::TrophyCreation;

const TASK_ID: felt252 = 'ArcadeConsecutiveWin';
const GROUP_NAME: felt252 = 'Arcade Consecutive Win';

fn arcade_consecutive_win_3() -> TrophyCreation {
    let description: ByteArray = "Won 3 consecutive Arcade battles";
    TrophyCreation {
        id: 'arcade_consecutive_win_3',
        hidden: false,
        index: 1,
        points: 10,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: 'chess-pawn',
        title: 'Arcade Strategist I',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 3, description },].span(),
        data: "",
    }
}

fn arcade_consecutive_win_5() -> TrophyCreation {
    let description: ByteArray = "Won 5 consecutive Arcade battles";
    TrophyCreation {
        id: 'arcade_consecutive_win_5',
        hidden: false,
        index: 2,
        points: 20,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: 'chess-knight',
        title: 'Arcade Strategist II',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 5, description },].span(),
        data: "",
    }
}

fn arcade_consecutive_win_10() -> TrophyCreation {
    let description: ByteArray = "Won 10 consecutive Arcade battles";
    TrophyCreation {
        id: 'arcade_consecutive_win_10',
        hidden: false,
        index: 3,
        points: 50,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: 'chess-queen',
        title: 'Arcade Strategist III',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 10, description },].span(),
        data: "",
    }
}

fn arcade_consecutive_win_20() -> TrophyCreation {
    let description: ByteArray = "Won 20 consecutive Arcade battles";
    TrophyCreation {
        id: 'arcade_consecutive_win_20',
        hidden: false,
        index: 4,
        points: 100,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: 'chess-king',
        title: 'Arcade Strategist IV',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 20, description },].span(),
        data: "",
    }
}
