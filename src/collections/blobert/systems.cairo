use dojo::{
    world::WorldStorage, event::EventStorage, model::{ModelStorage, ModelValueStorage, Model},
};
use blob_arena::{attacks::{AttackTrait, components::AttackInput}, stats::UStats, tags::IdTagNew};

use super::{
    BlobertStorage, Seed, BlobertItemKey, TokenAttributes, AttackSlot,
    components::{SeedTrait, TokenAttributesTrait},
};


#[generate_trait]
impl BlobertImpl of BlobertTrait {
    fn set_blobert_item_with_attacks(
        ref self: WorldStorage,
        key: BlobertItemKey,
        name: ByteArray,
        stats: UStats,
        attacks: Array<IdTagNew<AttackInput>>,
    ) {
        self.set_blobert_item(key, name, stats);
        self.fill_blobert_item_attack_slots(key, self.create_or_get_attacks_external(attacks));
    }

    fn get_blobert_stats(self: @WorldStorage, blobert: TokenAttributes) -> UStats {
        match blobert {
            TokenAttributes::Seed(seed) => { self.get_item_stats_sum(seed.to_item_keys()) },
            TokenAttributes::Custom(custom) => {
                self.get_item_stats(BlobertItemKey::Custom(custom))
            },
        }
    }

    fn get_blobert_attack(
        self: @WorldStorage, blobert: TokenAttributes, item_id: felt252, slot: felt252,
    ) -> felt252 {
        match blobert.to_item_key(item_id) {
            Option::Some(key) => self.get_blobert_attack_slot(key, slot),
            Option::None => 0,
        }
    }

    fn get_blobert_attacks(
        self: @WorldStorage, blobert: TokenAttributes, item_slots: Array<(felt252, felt252)>,
    ) -> Array<felt252> {
        let mut keys = ArrayTrait::<(BlobertItemKey, felt252)>::new();
        for (item_id, slot) in item_slots {
            match blobert.to_item_key(item_id) {
                Option::Some(key) => { keys.append((key, slot)); },
                Option::None => {},
            };
        };
        self.get_blobert_attack_slots(keys.span())
    }
}

