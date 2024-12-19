use blob_arena::{DefaultStorage, stats::UStats, attacks::components::AttackInput};
use super::{BlobertItemKey, BlobertAttribute, BlobertStorage, BlobertTrait, to_seed_key};


#[starknet::interface]
trait IBlobertItems<TContractState> {
    fn set_item(ref self: TContractState, key: BlobertItemKey, name: ByteArray, stats: UStats);
    fn set_item_with_attacks(
        ref self: TContractState,
        key: BlobertItemKey,
        name: ByteArray,
        stats: UStats,
        attacks: Array<AttackInput>
    );
    fn set_item_stats(ref self: TContractState, key: BlobertItemKey, stats: UStats);
    fn set_item_name(ref self: TContractState, key: BlobertItemKey, name: ByteArray);
    fn set_item_attack_slot(
        ref self: TContractState, key: BlobertItemKey, slot: felt252, attack_id: felt252
    );
    fn fill_item_attack_slots(ref self: TContractState, key: BlobertItemKey, slots: Array<felt252>);
    fn set_seed_item(
        ref self: TContractState,
        attribute: BlobertAttribute,
        id: u32,
        name: ByteArray,
        stats: UStats
    );
    fn set_seed_item_with_attacks(
        ref self: TContractState,
        attribute: BlobertAttribute,
        id: u32,
        name: ByteArray,
        stats: UStats,
        attacks: Array<AttackInput>
    );
    fn set_custom_item(ref self: TContractState, id: felt252, name: ByteArray, stats: UStats);
    fn set_custom_item_with_attacks(
        ref self: TContractState,
        id: felt252,
        name: ByteArray,
        stats: UStats,
        attacks: Array<AttackInput>
    );
}

#[starknet::embeddable]
impl IBlobertItemsImpl<
    TContractState, +DefaultStorage<TContractState>, +Drop<TContractState>
> of IBlobertItems<TContractState> {
    fn set_item(ref self: TContractState, key: BlobertItemKey, name: ByteArray, stats: UStats) {
        let mut storage = self.default_storage();
        storage.set_blobert_item(key, name, stats);
    }

    fn set_item_with_attacks(
        ref self: TContractState,
        key: BlobertItemKey,
        name: ByteArray,
        stats: UStats,
        attacks: Array<AttackInput>
    ) {
        let mut storage = self.default_storage();
        storage.set_blobert_item_with_attacks(key, name, stats, attacks);
    }

    fn set_item_stats(ref self: TContractState, key: BlobertItemKey, stats: UStats) {
        let mut storage = self.default_storage();
        storage.set_blobert_item_stats(key, stats);
    }

    fn set_item_name(ref self: TContractState, key: BlobertItemKey, name: ByteArray) {
        let mut storage = self.default_storage();
        storage.set_blobert_item_name(key, name);
    }

    fn set_item_attack_slot(
        ref self: TContractState, key: BlobertItemKey, slot: felt252, attack_id: felt252
    ) {
        let mut storage = self.default_storage();
        storage.set_blobert_item_attack_slot(key, slot, attack_id);
    }

    fn fill_item_attack_slots(
        ref self: TContractState, key: BlobertItemKey, slots: Array<felt252>
    ) {
        let mut storage = self.default_storage();
        storage.fill_blobert_item_attack_slots(key, slots);
    }

    fn set_seed_item(
        ref self: TContractState,
        attribute: BlobertAttribute,
        id: u32,
        name: ByteArray,
        stats: UStats
    ) {
        let mut storage = self.default_storage();
        storage.set_blobert_item(to_seed_key(attribute, id), name, stats);
    }

    fn set_seed_item_with_attacks(
        ref self: TContractState,
        attribute: BlobertAttribute,
        id: u32,
        name: ByteArray,
        stats: UStats,
        attacks: Array<AttackInput>
    ) {
        let mut storage = self.default_storage();
        storage.set_blobert_item_with_attacks(to_seed_key(attribute, id), name, stats, attacks);
    }

    fn set_custom_item(ref self: TContractState, id: felt252, name: ByteArray, stats: UStats) {
        let mut storage = self.default_storage();
        storage.set_blobert_item(BlobertItemKey::Custom(id), name, stats);
    }

    fn set_custom_item_with_attacks(
        ref self: TContractState,
        id: felt252,
        name: ByteArray,
        stats: UStats,
        attacks: Array<AttackInput>
    ) {
        let mut storage = self.default_storage();
        storage.set_blobert_item_with_attacks(BlobertItemKey::Custom(id), name, stats, attacks);
    }
}

