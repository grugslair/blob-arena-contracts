use dojo::{
    world::WorldStorage, event::EventStorage, model::{ModelStorage, ModelValueStorage, Model}
};
use blob_arena::{
    attacks::{AttackStorage, components::AttackInput}, items::ItemStorage, stats::UStats
};
#[generate_trait]
impl ItemImpl of ItemTrait {
    fn create_new_item_with_attacks(
        ref self: WorldStorage, name: ByteArray, stats: UStats, attacks: Array<AttackInput>
    ) -> felt252 {
        let item_id = self.create_item(name, stats);
        self.set_has_attacks(item_id, self.create_attacks(attacks));
        item_id
    }
}

