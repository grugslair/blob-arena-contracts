
use dojo::world::WorldStorage;
use achievement::
const ACHIEVEMENTS_NAMESPACE_HASH: felt252 = bytearray_hash!("achievements");

fn create_achievements(world: WorldStorage){

}

pub struct Task {
    id: felt252,
    total: u32,
    description: ByteArray,
}


fn somehting(){
    let kill_100 = Task{
        id: 'kill',
        total: 100,
        description: "Kill 100 enemies",
    };

    let kill_100 = Task{
        id: 'kill',
        total: 1000,
        description: "Kill 1000 enemies",
    };




    




}




#[generate_trait]
impl AchievementsImpl<const NAMESPACE_HASH: felt252> of AchievementsTrait{
    fn create_achievements(self, )
}