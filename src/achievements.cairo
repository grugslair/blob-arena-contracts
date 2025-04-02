use dojo::world::WorldStorage;
use achievement::types::task::Task;
use achievement::events::creation::{TrophyCreation, CreationTrait};

const ACHIEVEMENTS_NAMESPACE_HASH: felt252 = bytearray_hash!("achievements");

fn create_achievements(world: WorldStorage) {}


fn achievements() -> Span<TrophyCreation> {
    [
        TrophyCreation {
            id: 'start-arcade',
            hidden: false,
            index: 1,
            points: 10,
            start: 0,
            end: 0,
            group: 0,
            icon: 'something',
            title: 'Start Arcade',
            description: "Play some arcade games",
            tasks: [Task { id: 'start-arcade', total: 1, description: "Play an arcade games" }]
                .span(),
            data: "",
        },
        TrophyCreation {
            id: 'start-pvp',
            hidden: false,
            index: 2,
            points: 10,
            start: 0,
            end: 0,
            group: 0,
            icon: 'something',
            title: 'Start PVP',
            description: "Play some pvp games",
            tasks: [Task { id: 'start-pvp', total: 1, description: "Play some pvp games" }].span(),
            data: "",
        },
    ]
        .span()
}
