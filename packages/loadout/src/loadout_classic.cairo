use ba_blobert::BlobertTrait;
use crate::attack::IdTagAttack;
use crate::attributes::{Attributes, PartialAttributes};

#[starknet::interface]
pub trait IClassicLoadout<TContractState> {
    fn set_base_attributes(ref self: TContractState, attributes: Attributes);
    fn set_loadout(
        ref self: TContractState,
        blobert_trait: BlobertTrait,
        index: u32,
        name: ByteArray,
        attributes: PartialAttributes,
        attacks: Array<IdTagAttack>,
    );

    fn set_loadouts(ref self: TContractState, loadouts: Array<LoadoutInput>);
}

/// Input structure for setting multiple loadouts in batch operations
///
/// # Fields
/// * `blobert_trait` - The type/category of blobert this loadout applies to
/// * `index` - The specific index within the blobert trait category
/// * `name` - Human-readable name for this loadout configuration
/// * `attributes` - Partial attribute modifiers applied by this loadout
/// * `attacks` - Array of attacks available to this loadout configuration
#[derive(Drop, Serde)]
struct LoadoutInput {
    blobert_trait: BlobertTrait,
    index: u32,
    name: ByteArray,
    attributes: PartialAttributes,
    attacks: Array<IdTagAttack>,
}

/// Represents an attack assigned to a specific slot for a blobert loadout
///
/// # Fields
/// * `blobert_trait` - The type/category of blobert this attack slot belongs to
/// * `index` - The specific index within the blobert trait category
/// * `slot` - The slot number where this attack is assigned (0-based)
/// * `attack` - The unique identifier of the attack assigned to this slot
#[derive(Drop, Serde, Introspect)]
struct AttackSlot {
    blobert_trait: BlobertTrait,
    index: u32,
    slot: u32,
    attack: felt252,
}


/// Represents the complete ability set and attributes for a specific blobert configuration
///
/// This struct is used for storage and querying of blobert loadout data, containing both
/// identification information and the actual attribute values.
///
/// # Fields
/// ## Identification
/// * `blobert_trait` - The type/category of blobert
/// * `index` - The specific index within the blobert trait category
/// * `name` - Human-readable name for this blobert configuration
/// ## Abilities
///     From loadout
#[derive(Drop, Serde, Introspect)]
struct BlobertAbilities {
    blobert_trait: BlobertTrait,
    index: u32,
    name: ByteArray,
    strength: i8,
    vitality: i8,
    dexterity: i8,
    luck: i8,
    bludgeon_resistance: u8,
    magic_resistance: u8,
    pierce_resistance: u8,
    bludgeon_vulnerability: i16,
    magic_vulnerability: i16,
    pierce_vulnerability: i16,
}

#[starknet::contract]
mod loadout_classic {
    use ba_blobert::{
        BlobertTrait, BlobertTraitTrait, SeedTrait, TokenTraits, get_blobert_traits,
        get_custom_index,
    };
    use beacon_library::{ToriiTable, register_table_with_schema};
    use core::num::traits::Zero;
    use sai_core_utils::poseidon_serde::PoseidonSerde;
    use sai_ownable::{OwnableTrait, ownable_component};
    use sai_packing::SHIFT_4B_FELT252;
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, Mutable, StorageBase, StorageMapReadAccess, StorageMapWriteAccess,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use crate::attack::{IAttackAdminDispatcher, IAttackAdminDispatcherTrait};
    use crate::attributes;
    use crate::attributes::{Attributes, AttributesTrait};
    use crate::interface::ILoadout;
    use super::{
        AttackSlot, BlobertAbilities, IClassicLoadout, IdTagAttack, LoadoutInput, PartialAttributes,
    };

    component!(path: ownable_component, storage: ownable, event: OwnableEvents);

    const ATTRIBUTE_TABLE_ID: felt252 = bytearrays_hash!("loadout_classic", "Attributes");
    const ATTACK_SLOT_TABLE_ID: felt252 = bytearrays_hash!("loadout_classic", "AttackSlots");

    impl AttributeTable = ToriiTable<ATTRIBUTE_TABLE_ID>;
    impl AttackSlotTable = ToriiTable<ATTACK_SLOT_TABLE_ID>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: ownable_component::Storage,
        collection_addresses: Map<ContractAddress, bool>,
        attack_dispatcher: IAttackAdminDispatcher,
        attributes: Map<felt252, PartialAttributes>,
        attack_slots: Map<felt252, felt252>,
        base_attributes: Attributes,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvents: ownable_component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        attack_dispatcher_address: ContractAddress,
        collection_addresses: Array<ContractAddress>,
    ) {
        self.grant_owner(owner);
        for address in collection_addresses {
            self.collection_addresses.write(address, true);
        }
        self
            .attack_dispatcher
            .write(IAttackAdminDispatcher { contract_address: attack_dispatcher_address });
        register_table_with_schema::<BlobertAbilities>("loadout_classic", "Attributes");
        register_table_with_schema::<AttackSlot>("loadout_classic", "AttackSlots");
    }

    #[abi(embed_v0)]
    impl IOwnableImpl = ownable_component::OwnableImpl<ContractState>;

    #[abi(embed_v0)]
    impl ILoadoutImpl of ILoadout<ContractState> {
        fn attributes(
            self: @ContractState, collection_address: ContractAddress, token_id: u256,
        ) -> Attributes {
            self.assert_collection_address(collection_address);
            let attributes = match get_blobert_traits(collection_address, token_id) {
                TokenTraits::Seed(seed) => seed.indexes(),
                TokenTraits::Custom(index) => [get_custom_index(index)].span(),
            };
            self.get_combined_attributes(attributes)
        }
        fn attacks(
            self: @ContractState,
            collection_address: ContractAddress,
            token_id: u256,
            slots: Array<Array<felt252>>,
        ) -> Array<felt252> {
            self.assert_collection_address(collection_address);
            match get_blobert_traits(collection_address, token_id) {
                TokenTraits::Seed(seed) => self.get_seed_attack_slots(seed.indexes(), slots),
                TokenTraits::Custom(index) => self
                    .get_custom_attack_slots(get_custom_index(index), slots),
            }
        }

        fn loadout(
            self: @ContractState,
            collection_address: ContractAddress,
            token_id: u256,
            slots: Array<Array<felt252>>,
        ) -> (Attributes, Array<felt252>) {
            self.assert_collection_address(collection_address);
            let (indexes, attack_slots) = match get_blobert_traits(collection_address, token_id) {
                TokenTraits::Seed(seed) => {
                    let indexes = seed.indexes();
                    (indexes, self.get_seed_attack_slots(indexes, slots))
                },
                TokenTraits::Custom(index) => {
                    let cindex = get_custom_index(index);
                    ([cindex].span(), self.get_custom_attack_slots(cindex, slots))
                },
            };
            (self.get_combined_attributes(indexes), attack_slots)
        }
    }

    #[abi(embed_v0)]
    impl IClassicLoadoutImpl of IClassicLoadout<ContractState> {
        fn set_base_attributes(ref self: ContractState, attributes: Attributes) {
            self.assert_caller_is_owner();
            self.base_attributes.write(attributes);
        }

        fn set_loadout(
            ref self: ContractState,
            blobert_trait: BlobertTrait,
            index: u32,
            name: ByteArray,
            attributes: PartialAttributes,
            attacks: Array<IdTagAttack>,
        ) {
            self.assert_caller_is_owner();
            let abilities_index = blobert_trait.index(index);
            self.attributes.write(abilities_index, attributes);

            let attack_ids = self.attack_dispatcher.read().maybe_create_attacks(attacks);
            self.set_item_loadout(blobert_trait, index, name, attributes, attack_ids);
        }


        fn set_loadouts(ref self: ContractState, loadouts: Array<LoadoutInput>) {
            self.assert_caller_is_owner();
            let mut all_attacks: Array<Array<IdTagAttack>> = Default::default();
            for loadout in loadouts.span() {
                all_attacks.append(loadout.attacks.clone());
            }
            let attack_dispatcher = self.attack_dispatcher.read();
            let all_attack_ids = attack_dispatcher.maybe_create_attacks_array(all_attacks);
            for (loadout, attack_ids) in loadouts.into_iter().zip(all_attack_ids) {
                self
                    .set_item_loadout(
                        loadout.blobert_trait,
                        loadout.index,
                        loadout.name,
                        loadout.attributes,
                        attack_ids,
                    );
            }
        }
    }

    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn assert_collection_address(self: @ContractState, collection_address: ContractAddress) {
            assert(
                self.collection_addresses.read(collection_address), 'Invalid collection address',
            );
        }
        fn clip_attack_slot_slots(
            self: StorageBase<Mutable<Map<felt252, felt252>>>, slot_index: felt252, slots: u32,
        ) {
            let mut slots: felt252 = slots.into();
            let mut slot_ids: Array<felt252> = Default::default();
            loop {
                let slot_id = slot_index + slots.into();
                if self.read(slot_id).is_non_zero() {
                    self.write(slot_id, 0);
                    slot_ids.append(slot_id);
                    slots += 1;
                } else {
                    break;
                }
            }
            AttackSlotTable::delete_entities(slot_ids);
        }

        fn set_item_loadout(
            ref self: ContractState,
            blobert_trait: BlobertTrait,
            index: u32,
            name: ByteArray,
            attributes: PartialAttributes,
            attacks: Array<felt252>,
        ) {
            let item_index = blobert_trait.index(index);
            self.attributes.write(item_index, attributes);
            AttributeTable::set_entity(item_index, @(blobert_trait, index, name, attributes));
            let slot_index = item_index * SHIFT_4B_FELT252;
            self.attack_slots.clip_attack_slot_slots(slot_index, attacks.len());
            for (slot, attack_id) in attacks.into_iter().enumerate() {
                let slot_id = slot_index + slot.into();
                AttackSlotTable::set_entity(slot_id, @(blobert_trait, index, slot, attack_id));
                self.attack_slots.write(slot_id, attack_id);
            }
        }

        fn get_partial_attributes(
            self: @ContractState, indexes: Span<felt252>,
        ) -> Array<PartialAttributes> {
            indexes.into_iter().map(|k| self.attributes.read(*k)).collect()
        }
        fn get_combined_attributes(self: @ContractState, indexes: Span<felt252>) -> Attributes {
            let attributes = self.get_partial_attributes(indexes);
            self.base_attributes.read().add_partial_attributes(attributes)
        }

        fn get_seed_attack_slots(
            self: @ContractState, hashes: Span<felt252>, slots: Array<Array<felt252>>,
        ) -> Array<felt252> {
            slots
                .into_iter()
                .map(
                    |ks| {
                        let [key, slot]: [u32; 2] = ks.try_into().expect('Invalid slot format');
                        self.attack_slots.read(*hashes[key] * SHIFT_4B_FELT252 + slot.into())
                    },
                )
                .collect()
        }

        fn get_custom_attack_slots(
            self: @ContractState, abilities_index: felt252, slots: Array<Array<felt252>>,
        ) -> Array<felt252> {
            let slot_index = abilities_index * SHIFT_4B_FELT252;
            slots.into_iter().map(|slot| self.attack_slots.read(slot_index + *slot[0])).collect()
        }
    }

    impl Felt252ArrayTryIntoU32FixedArray2 of TryInto<Array<felt252>, [u32; 2]> {
        fn try_into(mut self: Array<felt252>) -> Option<[u32; 2]> {
            match self.len() == 2 {
                true => Some([(*self[0]).try_into()?, (*self[1]).try_into()?]),
                false => None,
            }
        }
    }
}

