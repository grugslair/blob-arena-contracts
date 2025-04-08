use achievement::types::task::Task;
use achievement::events::creation::TrophyCreation;

const TASK_ID: felt252 = 'PvpWagerWin';
const GROUP_NAME: felt252 = 'PvP Wager Win';

fn pvp_wager_win_5() -> TrophyCreation {
    let description: ByteArray = "Achieved 5 PvP wager wins of $2 or more";
    TrophyCreation {
        id: 'pvp_wager_win_5',
        hidden: false,
        index: 1,
        points: 10,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: 'coin',
        title: 'Wager Champion I',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 5, description },].span(),
        data: "",
    }
}

fn pvp_wager_win_20() -> TrophyCreation {
    let description: ByteArray = "Achieved 20 PvP wager wins of $2 or more";
    TrophyCreation {
        id: 'pvp_wager_win_20',
        hidden: false,
        index: 2,
        points: 20,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: 'coins',
        title: 'Wager Champion II',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 20, description },].span(),
        data: "",
    }
}

fn pvp_wager_win_50() -> TrophyCreation {
    let description: ByteArray = "Achieved 50 PvP wager wins of $2 or more";
    TrophyCreation {
        id: 'pvp_wager_win_50',
        hidden: false,
        index: 3,
        points: 30,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: 'money-bill',
        title: 'Wager Champion III',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 50, description },].span(),
        data: "",
    }
}

fn pvp_wager_win_200() -> TrophyCreation {
    let description: ByteArray = "Achieved 200 PvP wager wins of $2 or more";
    TrophyCreation {
        id: 'pvp_wager_win_200',
        hidden: false,
        index: 4,
        points: 40,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: 'sack-dollar',
        title: 'Wager Champion IV',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 200, description },].span(),
        data: "",
    }
}
