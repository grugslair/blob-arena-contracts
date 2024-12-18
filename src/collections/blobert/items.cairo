use blob_arena::{DefaultStorage, stats::UStats, attacks::components::AttackInput};
use super::{BlobertItemKey, BlobertAttribute, BlobertStorage, BlobertTrait, to_seed_key};


#[starknet::interface]
trait IBlobertItems<TContractState> {
    fn set_item(
        ref self: TContractState, item_id: BlobertItemKey, item_name: ByteArray, stats: UStats
    );
    fn set_item_with_attacks(
        ref self: TContractState,
        item_id: BlobertItemKey,
        item_name: ByteArray,
        stats: UStats,
        attacks: Array<AttackInput>
    );
    fn set_item_stats(ref self: TContractState, item_id: BlobertItemKey, stats: UStats);
    fn set_item_name(ref self: TContractState, item_id: BlobertItemKey, item_name: ByteArray);
    fn set_item_attack_slot(
        ref self: TContractState, item_id: BlobertItemKey, slot: felt252, attack_id: felt252
    );
    fn fill_item_attack_slots(
        ref self: TContractState, item_id: BlobertItemKey, slots: Array<felt252>
    );
    fn set_seed_item(
        ref self: TContractState,
        attribute: BlobertAttribute,
        attribute_id: u32,
        item_name: ByteArray,
        stats: UStats
    );
    fn set_seed_item_with_attacks(
        ref self: TContractState,
        attribute: BlobertAttribute,
        attribute_id: u32,
        item_name: ByteArray,
        stats: UStats,
        attacks: Array<AttackInput>
    );
    fn set_custom_item(
        ref self: TContractState, custom_id: felt252, item_name: ByteArray, stats: UStats
    );
    fn set_custom_item_with_attacks(
        ref self: TContractState,
        custom_id: felt252,
        item_name: ByteArray,
        stats: UStats,
        attacks: Array<AttackInput>
    );
}

#[starknet::embeddable]
impl IBlobertItemsImpl<
    TContractState, +DefaultStorage<TContractState>, +Drop<TContractState>
> of IBlobertItems<TContractState> {
    fn set_item(
        ref self: TContractState, item_id: BlobertItemKey, item_name: ByteArray, stats: UStats
    ) {
        let mut storage = self.default_storage();
        storage.set_blobert_item(item_id, item_name, stats);
    }

    fn set_item_with_attacks(
        ref self: TContractState,
        item_id: BlobertItemKey,
        item_name: ByteArray,
        stats: UStats,
        attacks: Array<AttackInput>
    ) {
        let mut storage = self.default_storage();
        storage.set_blobert_item_with_attacks(item_id, item_name, stats, attacks);
    }

    fn set_item_stats(ref self: TContractState, item_id: BlobertItemKey, stats: UStats) {
        let mut storage = self.default_storage();
        storage.set_blobert_item_stats(item_id, stats);
    }

    fn set_item_name(ref self: TContractState, item_id: BlobertItemKey, item_name: ByteArray) {
        let mut storage = self.default_storage();
        storage.set_blobert_item_name(item_id, item_name);
    }

    fn set_item_attack_slot(
        ref self: TContractState, item_id: BlobertItemKey, slot: felt252, attack_id: felt252
    ) {
        let mut storage = self.default_storage();
        storage.set_blobert_item_attack_slot(item_id, slot, attack_id);
    }

    fn fill_item_attack_slots(
        ref self: TContractState, item_id: BlobertItemKey, slots: Array<felt252>
    ) {
        let mut storage = self.default_storage();
        storage.fill_blobert_item_attack_slots(item_id, slots);
    }

    fn set_seed_item(
        ref self: TContractState,
        attribute: BlobertAttribute,
        attribute_id: u32,
        item_name: ByteArray,
        stats: UStats
    ) {
        let mut storage = self.default_storage();
        storage.set_blobert_item(to_seed_key(attribute, attribute_id), item_name, stats);
    }

    fn set_seed_item_with_attacks(
        ref self: TContractState,
        attribute: BlobertAttribute,
        attribute_id: u32,
        item_name: ByteArray,
        stats: UStats,
        attacks: Array<AttackInput>
    ) {
        let mut storage = self.default_storage();
        storage
            .set_blobert_item_with_attacks(
                to_seed_key(attribute, attribute_id), item_name, stats, attacks
            );
    }

    fn set_custom_item(
        ref self: TContractState, custom_id: felt252, item_name: ByteArray, stats: UStats
    ) {
        let mut storage = self.default_storage();
        storage.set_blobert_item(BlobertItemKey::Custom(custom_id), item_name, stats);
    }

    fn set_custom_item_with_attacks(
        ref self: TContractState,
        custom_id: felt252,
        item_name: ByteArray,
        stats: UStats,
        attacks: Array<AttackInput>
    ) {
        let mut storage = self.default_storage();
        storage
            .set_blobert_item_with_attacks(
                BlobertItemKey::Custom(custom_id), item_name, stats, attacks
            );
    }
}

