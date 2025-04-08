use achievement::types::task::Task;
use achievement::events::creation::TrophyCreation;

const TASK_ID: felt252 = 'CriticalHits';
const GROUP_NAME: felt252 = 'Critical Hits';

fn critical_hits_20() -> TrophyCreation {
    let description: ByteArray = "Landed 20 critical hits across all Bloberts";
    TrophyCreation {
        id: 'critical_hits_20',
        hidden: false,
        index: 1,
        points: 10,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: 'bullseye',
        title: 'Deadeye I',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 20, description },].span(),
        data: "",
    }
}

fn critical_hits_50() -> TrophyCreation {
    let description: ByteArray = "Landed 50 critical hits across all Bloberts";
    TrophyCreation {
        id: 'critical_hits_50',
        hidden: false,
        index: 2,
        points: 20,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: 'crosshairs',
        title: 'Deadeye II',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 50, description },].span(),
        data: "",
    }
}

fn critical_hits_200() -> TrophyCreation {
    let description: ByteArray = "Landed 200 critical hits across all Bloberts";
    TrophyCreation {
        id: 'critical_hits_200',
        hidden: false,
        index: 3,
        points: 30,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: 'burst',
        title: 'Deadeye III',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 200, description },].span(),
        data: "",
    }
}

fn critical_hits_500() -> TrophyCreation {
    let description: ByteArray = "Landed 500 critical hits across all Bloberts";
    TrophyCreation {
        id: 'critical_hits_500',
        hidden: false,
        index: 4,
        points: 40,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: 'skull-crossbones',
        title: 'Deadeye IV',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 500, description },].span(),
        data: "",
    }
}
