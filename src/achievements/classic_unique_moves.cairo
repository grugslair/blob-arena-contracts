use achievement::types::task::Task;
use achievement::events::creation::TrophyCreation;

const TASK_ID: felt252 = 'ClassicUniqueMoves';
const GROUP_NAME: felt252 = 'Classic Unique Moves';

fn classic_unique_moves_10() -> TrophyCreation {
    let description: ByteArray = "Used 10 unique moves across all Classic Bloberts";
    TrophyCreation {
        id: 'classic_unique_moves_10',
        hidden: false,
        index: 1,
        points: 10,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: 'book',
        title: 'Scholar I',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 10, description },].span(),
        data: "",
    }
}

fn classic_unique_moves_50() -> TrophyCreation {
    let description: ByteArray = "Used 50 unique moves across all Classic Bloberts";
    TrophyCreation {
        id: 'classic_unique_moves_50',
        hidden: false,
        index: 2,
        points: 20,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: 'book-open-cover',
        title: 'Scholar II',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 50, description },].span(),
        data: "",
    }
}

fn classic_unique_moves_100() -> TrophyCreation {
    let description: ByteArray = "Used 100 unique moves across all Classic Bloberts";
    TrophyCreation {
        id: 'classic_unique_moves_100',
        hidden: false,
        index: 3,
        points: 30,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: 'book-sparkles',
        title: 'Scholar III',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 100, description },].span(),
        data: "",
    }
}

fn classic_unique_moves_200() -> TrophyCreation {
    let description: ByteArray = "Used 200 unique moves across all Classic Bloberts";
    TrophyCreation {
        id: 'classic_unique_moves_200',
        hidden: false,
        index: 4,
        points: 40,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: 'hat-wizard',
        title: 'Scholar IV',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 200, description },].span(),
        data: "",
    }
}
