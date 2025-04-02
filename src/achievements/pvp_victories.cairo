use achievement::types::task::Task;
use achievement::events::creation::TrophyCreation;

const TASK_ID: felt252 = 'pvp_victory';
const GROUP_NAME: felt252 = 'Pvp Victories';

fn pvp_victory_1() -> TrophyCreation {
    let description: ByteArray = "Win a pvp battle";
    TrophyCreation {
        id: 'pvp_victory_1',
        hidden: false,
        index: 1,
        points: 10,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: '',
        title: 'PVP Victory',
        description: description.clone(),
        tasks: [Task { id: TASK_ID, total: 1, description },].span(),
        data: "",
    }
}


fn pvp_victory_50() -> TrophyCreation {
    TrophyCreation {
        id: 'pvp_victory_50',
        hidden: false,
        index: 2,
        points: 50,
        start: 0,
        end: 0,
        group: GROUP_NAME,
        icon: '',
        title: 'PVP 50 Victories',
        description: "Win 50 pvp battles",
        tasks: [Task { id: TASK_ID, total: 50, description: "Win 50 pvp battles" },].span(),
        data: "",
    }
}
