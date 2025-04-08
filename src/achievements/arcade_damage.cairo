use achievement::types::task::Task;
use achievement::events::creation::TrophyCreation;

const TASK_ID: felt252 = 'ArcadeTotalDamage';
const GROUP_NAME: felt252 = 'Arcade Total Damage';

fn arcade_damage_1000() -> TrophyCreation {
    let description: ByteArray = "Dealt 1,000 total damage in Arcade Battles";
    TrophyCreation {
        id: 'arcade_damage_1000',
        hidden: false,
        index: 1,
        points: 10,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: 'sparkle',
        title: 'Damage Dealer I',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 1000, description },].span(),
        data: "",
    }
}

fn arcade_damage_5000() -> TrophyCreation {
    let description: ByteArray = "Dealt 5,000 total damage in Arcade Battles";
    TrophyCreation {
        id: 'arcade_damage_5000',
        hidden: false,
        index: 2,
        points: 20,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: 'sparkles',
        title: 'Damage Dealer II',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 5000, description },].span(),
        data: "",
    }
}

fn arcade_damage_20000() -> TrophyCreation {
    let description: ByteArray = "Dealt 20,000 total damage in Arcade Battles";
    TrophyCreation {
        id: 'arcade_damage_20000',
        hidden: false,
        index: 3,
        points: 40,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: 'fire',
        title: 'Damage Dealer III',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 20000, description },].span(),
        data: "",
    }
}

fn arcade_damage_50000() -> TrophyCreation {
    let description: ByteArray = "Dealt 50,000 total damage in Arcade Battles";
    TrophyCreation {
        id: 'arcade_damage_50000',
        hidden: false,
        index: 4,
        points: 80,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: 'explosion',
        title: 'Damage Dealer IV',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 50000, description },].span(),
        data: "",
    }
}
