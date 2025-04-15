use crate::stats::UStats;
use crate::tags::IdTagNew;
use crate::attacks::AttackInput;

use super::super::{BlobertItemKey, BlobertAttribute};


/// Interface for managing Blobert items, their stats, names, and attacks
#[starknet::interface]
trait IBlobertItems<TContractState> {
    /// Sets both name and stats for a Blobert item
    /// * `key` - The unique identifier for the item
    /// * `name` - The name to set for the item
    /// * `stats` - The stats to set for the item
    ///
    /// Models:
    /// - BlobertItem
    ///
    /// Events:
    /// - BlobertItemName
    fn set_item(ref self: TContractState, key: BlobertItemKey, name: ByteArray, stats: UStats);

    /// Sets name, stats and attacks for a Blobert item
    /// * `key` - The unique identifier for the item
    /// * `name` - The name to set for the item
    /// * `stats` - The stats to set for the item
    /// * `attacks` - Array of attacks to assign to the item
    ///
    /// Models:
    /// - BlobertItem
    /// - AttackSlot
    /// - Attack
    ///
    /// Events:
    /// - BlobertItemName
    /// - AttackName
    fn set_item_with_attacks(
        ref self: TContractState,
        key: BlobertItemKey,
        name: ByteArray,
        stats: UStats,
        attacks: Array<IdTagNew<AttackInput>>,
    );

    /// Updates just the stats for an existing Blobert item
    /// * `key` - The unique identifier for the item
    /// * `stats` - The new stats to set
    ///
    /// Models:
    /// - BlobertItem
    fn set_item_stats(ref self: TContractState, key: BlobertItemKey, stats: UStats);

    /// Updates just the name for an existing Blobert item
    /// * `key` - The unique identifier for the item
    /// * `name` - The new name to set
    ///
    /// Events:
    /// - BlobertItemName
    fn set_item_name(ref self: TContractState, key: BlobertItemKey, name: ByteArray);

    /// Sets a single attack in a specific slot for a Blobert item
    /// * `key` - The unique identifier for the item
    /// * `slot` - The slot number to place the attack in
    /// * `attack` - The attack to set in the specified slot
    ///
    /// Models:
    /// - AttackSlot
    /// - Attack
    ///
    /// Events:
    /// - AttackName
    fn set_item_attack_slot(
        ref self: TContractState, key: BlobertItemKey, slot: felt252, attack: IdTagNew<AttackInput>,
    );

    /// Fills all attack slots for a Blobert item
    /// * `key` - The unique identifier for the item
    /// * `attacks` - Array of attacks to fill the slots with
    ///
    /// Models:
    /// - AttackSlot
    /// - Attack
    ///
    /// Events:
    /// - AttackName
    fn fill_item_attack_slots(
        ref self: TContractState, key: BlobertItemKey, attacks: Array<IdTagNew<AttackInput>>,
    );

    /// Creates a new seed item with specified attribute
    /// * `attribute` - The attribute type for the seed item
    /// * `id` - Unique identifier for the seed item
    /// * `name` - Name of the seed item
    /// * `stats` - Stats for the seed item
    ///
    /// Models:
    /// - BlobertItem
    ///
    /// Events:
    /// - BlobertItemName
    fn set_seed_item(
        ref self: TContractState,
        attribute: BlobertAttribute,
        id: u32,
        name: ByteArray,
        stats: UStats,
    );

    /// Creates a new seed item with attacks
    /// * `attribute` - The attribute type for the seed item
    /// * `id` - Unique identifier for the seed item
    /// * `name` - Name of the seed item
    /// * `stats` - Stats for the seed item
    /// * `attacks` - Array of attacks for the seed item
    ///
    /// Models:
    /// - BlobertItem
    /// - AttackSlot
    /// - Attack
    ///
    /// Events:
    /// - BlobertItemName
    /// - AttackName
    fn set_seed_item_with_attacks(
        ref self: TContractState,
        attribute: BlobertAttribute,
        id: u32,
        name: ByteArray,
        stats: UStats,
        attacks: Array<IdTagNew<AttackInput>>,
    );

    /// Creates a custom item with specified parameters
    /// * `id` - Custom identifier for the item
    /// * `name` - Name of the custom item
    /// * `stats` - Stats for the custom item
    ///
    /// Models:
    /// - BlobertItem
    ///
    /// Events:
    /// - BlobertItemName
    fn set_custom_item(ref self: TContractState, id: felt252, name: ByteArray, stats: UStats);

    /// Creates a custom item with attacks
    /// * `id` - Custom identifier for the item
    /// * `name` - Name of the custom item
    /// * `stats` - Stats for the custom item
    /// * `attacks` - Array of attacks for the custom item
    ///
    /// Models:
    /// - BlobertItem
    /// - AttackSlot
    /// - Attack
    ///
    /// Events:
    /// - BlobertItemName
    /// - AttackName
    fn set_custom_item_with_attacks(
        ref self: TContractState,
        id: felt252,
        name: ByteArray,
        stats: UStats,
        attacks: Array<IdTagNew<AttackInput>>,
    );
}

mod cmp {
    use dojo::world::WorldStorage;

    use crate::permissions::{Permissions, Role};
    use crate::world::{WorldDispatcher, WorldComponent};
    use crate::attacks::AttackTrait;

    use super::{BlobertItemKey, UStats, AttackInput, IdTagNew, BlobertAttribute};
    use super::super::{BlobertItemsTrait, BlobertItemStorage};
    use super::super::super::to_seed_key;

    #[starknet::embeddable]
    impl IBlobertItemsImpl<
        TContractState,
        const ROLE: Role,
        impl BlobertStore: super::super::super::BlobertStore,
        +Drop<TContractState>,
        +WorldComponent<TContractState>,
    > of super::IBlobertItems<TContractState> {
        fn set_item(ref self: TContractState, key: BlobertItemKey, name: ByteArray, stats: UStats) {
            let dispactcher = self.world_dispatcher();
            dispactcher.assert_caller_has_permission(ROLE);
            let mut storage = dispactcher.item_store();
            storage.set_blobert_item(key, name, stats);
        }

        fn set_item_with_attacks(
            ref self: TContractState,
            key: BlobertItemKey,
            name: ByteArray,
            stats: UStats,
            attacks: Array<IdTagNew<AttackInput>>,
        ) {
            let dispactcher = self.world_dispatcher();
            dispactcher.assert_caller_has_permission(ROLE);
            let mut storage = dispactcher.item_store();
            storage.set_blobert_item_with_attacks(key, name, stats, attacks);
        }

        fn set_item_stats(ref self: TContractState, key: BlobertItemKey, stats: UStats) {
            let dispactcher = self.world_dispatcher();
            dispactcher.assert_caller_has_permission(ROLE);
            let mut storage = dispactcher.item_store();
            storage.set_blobert_item_stats(key, stats);
        }

        fn set_item_name(ref self: TContractState, key: BlobertItemKey, name: ByteArray) {
            let dispactcher = self.world_dispatcher();
            dispactcher.assert_caller_has_permission(ROLE);
            let mut storage = dispactcher.item_store();
            storage.set_blobert_item_name(key, name);
        }

        fn set_item_attack_slot(
            ref self: TContractState,
            key: BlobertItemKey,
            slot: felt252,
            attack: IdTagNew<AttackInput>,
        ) {
            let dispactcher = self.world_dispatcher();
            dispactcher.assert_caller_has_permission(ROLE);
            let mut storage = dispactcher.item_store();
            let id = storage.create_or_get_attack_external(attack);
            storage.set_blobert_item_attack_slot(key, slot, id);
        }

        fn fill_item_attack_slots(
            ref self: TContractState, key: BlobertItemKey, attacks: Array<IdTagNew<AttackInput>>,
        ) {
            let dispactcher = self.world_dispatcher();
            dispactcher.assert_caller_has_permission(ROLE);
            let mut storage = dispactcher.item_store();
            let ids = storage.create_or_get_attacks_external(attacks);
            storage.fill_blobert_item_attack_slots(key, ids);
        }

        fn set_seed_item(
            ref self: TContractState,
            attribute: BlobertAttribute,
            id: u32,
            name: ByteArray,
            stats: UStats,
        ) {
            let dispactcher = self.world_dispatcher();
            dispactcher.assert_caller_has_permission(ROLE);
            let mut storage = dispactcher.item_store();
            storage.set_blobert_item(to_seed_key(attribute, id), name, stats);
        }

        fn set_seed_item_with_attacks(
            ref self: TContractState,
            attribute: BlobertAttribute,
            id: u32,
            name: ByteArray,
            stats: UStats,
            attacks: Array<IdTagNew<AttackInput>>,
        ) {
            let dispactcher = self.world_dispatcher();
            dispactcher.assert_caller_has_permission(ROLE);
            let mut storage = dispactcher.item_store();
            storage.set_blobert_item_with_attacks(to_seed_key(attribute, id), name, stats, attacks);
        }

        fn set_custom_item(ref self: TContractState, id: felt252, name: ByteArray, stats: UStats) {
            let dispactcher = self.world_dispatcher();
            dispactcher.assert_caller_has_permission(ROLE);
            let mut storage = dispactcher.item_store();
            storage.set_blobert_item(BlobertItemKey::Custom(id), name, stats);
        }

        fn set_custom_item_with_attacks(
            ref self: TContractState,
            id: felt252,
            name: ByteArray,
            stats: UStats,
            attacks: Array<IdTagNew<AttackInput>>,
        ) {
            let dispactcher = self.world_dispatcher();
            dispactcher.assert_caller_has_permission(ROLE);
            let mut storage = dispactcher.item_store();
            storage.set_blobert_item_with_attacks(BlobertItemKey::Custom(id), name, stats, attacks);
        }
    }
}

