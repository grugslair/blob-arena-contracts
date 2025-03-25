use dojo::{
    world::WorldStorage, model::{ModelStorage, ModelValueStorage, Model}, event::EventStorage,
    utils::entity_id_from_keys,
};
use blob_arena::{stats::UStats, iter::Iteration, attacks::AttackStorage};
use super::super::{BlobertItemKey, BlobertAttribute, Seed, SeedItem, SeedTrait};

/// Setup Models

/// A struct representing an item that can be equipped by a Blobert
///
/// # Fields
/// * `key` - The unique identifier for this item, represented by a BlobertItemKey
/// * `stats` - The stats associated with this item, stored as UStats
///
/// # Notes
/// This is a Dojo model that can be dropped, serialized, and copied.
#[dojo::model]
#[derive(Drop, Serde, Copy)]
struct BlobertItem {
    #[key]
    key: BlobertItemKey,
    stats: UStats,
}


/// Contains a Blobert item's name information.
///
/// # Fields
/// * `id` - The unique identifier of the item
/// * `name` - The name of the item as a ByteArray
///
/// # Events
/// Emitted when a Blobert item's name is created or updated
#[dojo::event]
#[derive(Drop, Serde)]
struct BlobertItemName {
    #[key]
    id: felt252,
    name: ByteArray,
}

/// Represents an attack slot associated with a Blobert item
///
/// # Fields
/// * `item_key` - The unique identifier for the Blobert item
/// * `slot` - The slot position number
/// * `attack_id` - The identifier of the attack assigned to this slot
#[dojo::model]
#[derive(Drop, Serde)]
struct AttackSlot {
    #[key]
    item_key: BlobertItemKey,
    #[key]
    slot: felt252,
    attack_id: felt252,
}

#[generate_trait]
impl BlobertItemStorageImpl of BlobertItemStorage {
    fn set_blobert_item_stats(ref self: WorldStorage, key: BlobertItemKey, stats: UStats) {
        self.write_model(@BlobertItem { key, stats });
    }

    fn set_blobert_item_name(ref self: WorldStorage, key: BlobertItemKey, name: ByteArray) {
        self.emit_event(@BlobertItemName { id: entity_id_from_keys(@key), name });
    }

    fn set_blobert_item(
        ref self: WorldStorage, key: BlobertItemKey, name: ByteArray, stats: UStats,
    ) {
        self.set_blobert_item_stats(key, stats);
        self.set_blobert_item_name(key, name);
    }

    fn get_blobert_item_stats(self: @WorldStorage, key: BlobertItemKey) -> UStats {
        self.read_member(Model::<BlobertItem>::ptr_from_keys(key), selector!("stats"))
    }

    fn get_blobert_items_stats(self: @WorldStorage, keys: Span<BlobertItemKey>) -> Array<UStats> {
        self.read_member_of_models(Model::<BlobertItem>::ptrs_from_keys(keys), selector!("stats"))
    }

    fn get_item_stats_sum(self: @WorldStorage, keys: Span<BlobertItemKey>) -> UStats {
        let mut stats: UStats = Default::default();
        for item in self.get_blobert_items(keys) {
            stats += item.stats;
        };
        stats
    }

    fn get_blobert_attack_slot(
        self: @WorldStorage, item_key: BlobertItemKey, slot: felt252,
    ) -> felt252 {
        self
            .read_member(
                Model::<AttackSlot>::ptr_from_keys((item_key, slot)), selector!("attack_id"),
            )
    }

    fn get_blobert_attack_slots(
        self: @WorldStorage, item_slots: Span<(BlobertItemKey, felt252)>,
    ) -> Array<felt252> {
        self
            .read_member_of_models(
                Model::<AttackSlot>::ptrs_from_keys(item_slots), selector!("attack_id"),
            )
    }


    fn set_blobert_item_attack_slot(
        ref self: WorldStorage, item_key: BlobertItemKey, slot: felt252, attack_id: felt252,
    ) {
        self.write_model(@AttackSlot { item_key, slot, attack_id });
    }

    fn fill_blobert_item_attack_slots(
        ref self: WorldStorage, item_key: BlobertItemKey, attack_ids: Array<felt252>,
    ) {
        let mut models = ArrayTrait::<@AttackSlot>::new();
        for (slot, attack_id) in attack_ids.enumerate() {
            models.append(@AttackSlot { item_key, slot: slot.into(), attack_id });
        };
        self.write_models(models.span());
    }
}

