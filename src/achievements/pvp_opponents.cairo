use achievement::types::task::Task;
use achievement::events::creation::TrophyCreation;

const TASK_ID: felt252 = 'PvpUniqueOpponents';
const GROUP_NAME: felt252 = 'PvP Opponents';

fn pvp_opponents_5() -> TrophyCreation {
    let description: ByteArray = "Faced 5 players in PvP battles";
    TrophyCreation {
        id: 'pvp_opponents_5',
        hidden: false,
        index: 1,
        points: 10,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: 'user',
        title: 'Contender I',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 5, description },].span(),
        data: "",
    }
}

fn pvp_opponents_20() -> TrophyCreation {
    let description: ByteArray = "Faced 20 players in PvP battles";
    TrophyCreation {
        id: 'pvp_opponents_20',
        hidden: false,
        index: 2,
        points: 20,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: 'user-group',
        title: 'Contender II',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 20, description },].span(),
        data: "",
    }
}

fn pvp_opponents_50() -> TrophyCreation {
    let description: ByteArray = "Faced 50 players in PvP battles";
    TrophyCreation {
        id: 'pvp_opponents_50',
        hidden: false,
        index: 3,
        points: 30,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: 'users',
        title: 'Contender III',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 50, description },].span(),
        data: "",
    }
}

fn pvp_opponents_200() -> TrophyCreation {
    let description: ByteArray = "Faced 200 player in PvP battles";
    TrophyCreation {
        id: 'pvp_opponents_200',
        hidden: false,
        index: 4,
        points: 40,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: 'people-group',
        title: 'Contender IV',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 200, description },].span(),
        data: "",
    }
}
