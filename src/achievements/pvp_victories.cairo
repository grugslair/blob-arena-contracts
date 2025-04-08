use achievement::types::task::Task;
use achievement::events::creation::TrophyCreation;

const TASK_ID: felt252 = 'PvpBattleVictories';
const GROUP_NAME: felt252 = 'PvP Battle Victories';

fn pvp_victories_5() -> TrophyCreation {
    let description: ByteArray = "Won 5 PvP Battles";
    TrophyCreation {
        id: 'pvp_victories_5',
        hidden: false,
        index: 1,
        points: 10,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: 'wand',
        title: 'Duelist I',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 5, description },].span(),
        data: "",
    }
}

fn pvp_victories_20() -> TrophyCreation {
    let description: ByteArray = "Won 20 PvP Battles";
    TrophyCreation {
        id: 'pvp_victories_20',
        hidden: false,
        index: 2,
        points: 20,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: 'sword',
        title: 'Duelist II',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 20, description },].span(),
        data: "",
    }
}

fn pvp_victories_50() -> TrophyCreation {
    let description: ByteArray = "Won 50 PvP Battles";
    TrophyCreation {
        id: 'pvp_victories_50',
        hidden: false,
        index: 3,
        points: 30,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: 'axe-battle',
        title: 'Duelist III',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 50, description },].span(),
        data: "",
    }
}

fn pvp_victories_200() -> TrophyCreation {
    let description: ByteArray = "Won 200 PvP Battles";
    TrophyCreation {
        id: 'pvp_victories_200',
        hidden: false,
        index: 4,
        points: 40,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: 'swords',
        title: 'Duelist IV',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 200, description },].span(),
        data: "",
    }
}
