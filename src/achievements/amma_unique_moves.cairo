use achievement::types::task::Task;
use achievement::events::creation::TrophyCreation;

const TASK_ID: felt252 = 'AMMAUniqueMoves';
const GROUP_NAME: felt252 = 'AMMA Unique Moves';

fn amma_unique_moves_10() -> TrophyCreation {
    let description: ByteArray = "Used 10 unique moves across all AMMA Bloberts";
    TrophyCreation {
        id: 'amma_unique_moves_10',
        hidden: false,
        index: 1,
        points: 10,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: 'person-walking',
        title: 'Tactician I',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 10, description },].span(),
        data: "",
    }
}

fn amma_unique_moves_50() -> TrophyCreation {
    let description: ByteArray = "Used 50 unique moves across all AMMA Bloberts";
    TrophyCreation {
        id: 'amma_unique_moves_50',
        hidden: false,
        index: 2,
        points: 20,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: 'hand-fist',
        title: 'Tactician II',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 50, description },].span(),
        data: "",
    }
}

fn amma_unique_moves_100() -> TrophyCreation {
    let description: ByteArray = "Used 100 unique moves across all AMMA Bloberts";
    TrophyCreation {
        id: 'amma_unique_moves_100',
        hidden: false,
        index: 3,
        points: 30,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: 'person-running',
        title: 'Tactician III',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 100, description },].span(),
        data: "",
    }
}

fn amma_unique_moves_200() -> TrophyCreation {
    let description: ByteArray = "Used 200 unique moves across all AMMA Bloberts";
    TrophyCreation {
        id: 'amma_unique_moves_200',
        hidden: false,
        index: 4,
        points: 40,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: 'dumbbell',
        title: 'Tactician IV',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 200, description },].span(),
        data: "",
    }
}
