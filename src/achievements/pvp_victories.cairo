use achievement::types::task::Task;
use achievement::events::creation::TrophyCreation;

const PVP_VICTORIES_ID: felt252 = 'pvp-victory';

fn achievement() -> TrophyCreation {
    TrophyCreation {
        id: PVE_VICTORIES_ID,
        hidden: false,
        index: 1,
        points: 10,
        start: 0,
        end: 0,
        group: 0,
        icon: '',
        title: 'PVP Victories',
        description: "Win pvp battles",
        tasks: [
            Task { id: PVE_VICTORIES_ID, total: 1, description: "Win a pvp battle" },
            Task { id: PVE_VICTORIES_ID, total: 50, description: "Win 50 pvp battles" },
            Task { id: PVE_VICTORIES_ID, total: 500, description: "Win 500 pvp battles" },
        ]
            .span(),
        data: "",
    }
}
