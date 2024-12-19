use dojo::{
    world::WorldStorage, model::{ModelStorage, ModelValueStorage, Model}, event::EventStorage,
    utils::entity_id_from_keys
};
use blob_arena::{stats::UStats, core::Enumerate, attacks::AttackStorage};
use super::components::{
    BlobertItem, BlobertItemKey, BlobertAttribute, Seed, SeedItem, BlobertItemValue,
    BlobertItemName, SeedTrait, AttackSlot, AttackSlotValue
};

#[generate_trait]
impl BlobertStorageImpl of BlobertStorage {
    fn set_blobert_item_stats(ref self: WorldStorage, key: BlobertItemKey, stats: UStats) {
        self.write_model(@BlobertItem { key, stats });
    }

    fn set_blobert_item_name(ref self: WorldStorage, key: BlobertItemKey, name: ByteArray) {
        self.emit_event(@BlobertItemName { id: entity_id_from_keys(@key), name });
    }

    fn set_blobert_item(
        ref self: WorldStorage, key: BlobertItemKey, name: ByteArray, stats: UStats
    ) {
        self.set_blobert_item_stats(key, stats);
        self.set_blobert_item_name(key, name);
    }

    fn get_blobert_item(self: @WorldStorage, key: BlobertItemKey) -> BlobertItemValue {
        self.read_value(key)
    }

    fn get_blobert_items(
        self: @WorldStorage, keys: Span<BlobertItemKey>
    ) -> Array<BlobertItemValue> {
        self.read_values(keys)
    }

    fn get_item_stats(self: @WorldStorage, key: BlobertItemKey) -> UStats {
        self.read_member(Model::<BlobertItem>::ptr_from_keys(key), selector!("stats"))
    }

    fn get_item_stats_sum(self: @WorldStorage, keys: Span<BlobertItemKey>) -> UStats {
        let mut stats: UStats = Default::default();
        for item in self.get_blobert_items(keys) {
            stats += item.stats;
        };
        stats
    }

    fn get_blobert_attack_slot(
        self: @WorldStorage, item_key: BlobertItemKey, slot: felt252
    ) -> felt252 {
        self
            .read_member(
                Model::<AttackSlot>::ptr_from_keys((item_key, slot)), selector!("attack_id")
            )
    }

    fn get_blobert_attack_slots(
        self: @WorldStorage, item_slots: Span<(BlobertItemKey, felt252)>
    ) -> Array<felt252> {
        let values: Array<AttackSlotValue> = self.read_values(item_slots);
        let mut array = ArrayTrait::<felt252>::new();
        for value in values {
            array.append(value.attack_id);
        };
        array
    }


    fn set_blobert_item_attack_slot(
        ref self: WorldStorage, item_key: BlobertItemKey, slot: felt252, attack_id: felt252
    ) {
        self.write_model(@AttackSlot { item_key, slot, attack_id, });
    }

    fn fill_blobert_item_attack_slots(
        ref self: WorldStorage, item_key: BlobertItemKey, attack_ids: Array<felt252>
    ) {
        let mut models = ArrayTrait::<@AttackSlot>::new();
        for (slot, attack_id) in attack_ids
            .enumerate() {
                models.append(@AttackSlot { item_key, slot: slot.into(), attack_id });
            };
        self.write_models(models.span());
    }
}
