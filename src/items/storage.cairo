use dojo::{
    world::WorldStorage, event::EventStorage, model::{ModelStorage, ModelValueStorage, Model}
};
use blob_arena::{
    id_trait::IdsTrait, attacks::AttackStorage, items::{Item, components::{HasAttack, ItemName}},
    stats::UStats, uuid
};

#[generate_trait]
impl ItemStorageImpl of ItemStorage {
    fn get_item(self: @WorldStorage, id: felt252) -> Item {
        self.read_model(id)
    }
    fn get_items(self: @WorldStorage, ids: Span<felt252>) -> Array<Item> {
        self.read_models(ids)
    }
    fn create_item(ref self: WorldStorage, name: ByteArray, stats: UStats) -> felt252 {
        let id = uuid();

        self.write_model(@Item { id, stats });
        self.emit_event(@ItemName { id, name });
        id
    }
    fn set_has_attack(ref self: WorldStorage, item_id: felt252, attack_id: felt252) {
        self.write_model(@HasAttack { item_id, attack_id, has: true });
    }
    fn remove_has_attack(ref self: WorldStorage, item_id: felt252, attack_id: felt252) {
        self.erase_model_ptr(Model::<HasAttack>::ptr_from_keys((item_id, attack_id)));
    }
    fn set_has_attacks(ref self: WorldStorage, item_id: felt252, attack_ids: Span<felt252>) {
        let mut has_attacks = ArrayTrait::<@HasAttack>::new();
        for attack_id in attack_ids {
            has_attacks.append(@HasAttack { item_id, attack_id: *attack_id, has: true });
        };
        self.write_models(has_attacks.span());
    }
    fn get_items_stats(self: @WorldStorage, ids: Span<felt252>) -> Array<UStats> {
        let mut stats = ArrayTrait::<UStats>::new();
        for item in self.get_items(ids) {
            stats.append(item.stats);
        };
        stats
    }
}

