use ba_blobert::{BlobertAttribute, BlobertAttributeKey};
use crate::ability::Abilities;
use crate::attack::IdTagAttack;

#[starknet::interface]
pub trait IClassicBlobertLoadout<TContractState> {
    fn set_loadout(
        ref self: TContractState,
        key: BlobertAttributeKey,
        name: ByteArray,
        abilities: Abilities,
        attacks: Array<IdTagAttack>,
    );

    fn set_loadouts(ref self: TContractState, loadouts: Array<LoadoutInput>);
}

#[derive(Drop, Serde)]
struct LoadoutInput {
    key: BlobertAttributeKey,
    name: ByteArray,
    abilities: Abilities,
    attacks: Array<IdTagAttack>,
}


#[derive(Drop, Serde, Introspect)]
struct AttackSlot {
    attribute: BlobertAttribute,
    index: u32,
    slot: u32,
    attack: felt252,
}


#[derive(Drop, Serde, Introspect)]
struct BlobertAbilities {
    attribute: BlobertAttribute,
    index: u32,
    name: ByteArray,
    strength: u32,
    vitality: u32,
    dexterity: u32,
    luck: u32,
}

#[starknet::contract]
mod classic_blobert_loadout {
    use ba_blobert::{
        BlobertAttribute, BlobertAttributeKey, SeedTrait, TokenAttributes, get_blobert_attributes,
    };
    use beacon_library::{ToriiTable, register_table_with_schema};
    use core::num::traits::Zero;
    use sai_core_utils::poseidon_serde::PoseidonSerde;
    use sai_ownable::{OwnableTrait, ownable_component};
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, Mutable, StorageBase, StorageMapReadAccess, StorageMapWriteAccess,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use crate::ability::Abilities;
    use crate::attack::{IAttackAdminDispatcher, IAttackAdminDispatcherTrait};
    use crate::interface::ILoadout;
    use super::{AttackSlot, BlobertAbilities, IClassicBlobertLoadout, IdTagAttack, LoadoutInput};

    component!(path: ownable_component, storage: ownable, event: OwnableEvents);

    const ABILITY_TABLE_ID: felt252 = bytearrays_hash!(
        "classic_blobert_loadout", "ClassicBlobertAbility",
    );
    const ATTACK_SLOT_TABLE_ID: felt252 = bytearrays_hash!(
        "classic_blobert_loadout", "ClassicBlobertAttackSlot",
    );

    impl AbilityTable = ToriiTable<ABILITY_TABLE_ID>;
    impl AttackSlotTable = ToriiTable<ATTACK_SLOT_TABLE_ID>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: ownable_component::Storage,
        collection_addresses: Map<ContractAddress, bool>,
        attack_dispatcher: IAttackAdminDispatcher,
        seed_attack_slots: Map<felt252, felt252>,
        custom_attack_slots: Map<felt252, felt252>,
        seed_abilities: Map<felt252, Abilities>,
        custom_abilities: Map<felt252, Abilities>,
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
        register_table_with_schema::<
            BlobertAbilities,
        >("classic_blobert_loadout", "ClassicBlobertAbility");
        register_table_with_schema::<
            AttackSlot,
        >("classic_blobert_loadout", "ClassicBlobertAttackSlot");
    }

    #[abi(embed_v0)]
    impl IOwnableImpl = ownable_component::OwnableImpl<ContractState>;

    #[abi(embed_v0)]
    impl ILoadoutImpl of ILoadout<ContractState> {
        fn abilities(
            self: @ContractState, collection_address: ContractAddress, token_id: u256,
        ) -> Abilities {
            self.assert_collection_address(collection_address);
            match get_blobert_attributes(collection_address, token_id) {
                TokenAttributes::Seed(seed) => self.get_seed_attributes(seed.key_hashes().span()),
                TokenAttributes::Custom(key) => self.custom_abilities.read(key.into()),
            }
        }
        fn attacks(
            self: @ContractState,
            collection_address: ContractAddress,
            token_id: u256,
            slots: Array<Array<felt252>>,
        ) -> Array<felt252> {
            self.assert_collection_address(collection_address);
            match get_blobert_attributes(collection_address, token_id) {
                TokenAttributes::Seed(seed) => self
                    .get_seed_attack_slots(seed.key_hashes().span(), slots),
                TokenAttributes::Custom(key) => self.get_custom_attack_slots(key, slots),
            }
        }

        fn loadout(
            self: @ContractState,
            collection_address: ContractAddress,
            token_id: u256,
            slots: Array<Array<felt252>>,
        ) -> (Abilities, Array<felt252>) {
            self.assert_collection_address(collection_address);
            match get_blobert_attributes(collection_address, token_id) {
                TokenAttributes::Seed(seed) => {
                    let hashes = seed.key_hashes().span();
                    (self.get_seed_attributes(hashes), self.get_seed_attack_slots(hashes, slots))
                },
                TokenAttributes::Custom(key) => (
                    self.custom_abilities.read(key.into()),
                    self.get_custom_attack_slots(key, slots),
                ),
            }
        }
    }

    #[abi(embed_v0)]
    impl IClassicBlobertLoadoutImpl of IClassicBlobertLoadout<ContractState> {
        fn set_loadout(
            ref self: ContractState,
            key: BlobertAttributeKey,
            name: ByteArray,
            abilities: Abilities,
            attacks: Array<IdTagAttack>,
        ) {
            self.assert_caller_is_owner();
            let hash = key.poseidon_hash();
            self.get_abilities_ptr(key).write(hash, abilities);

            let attack_ids = self.attack_dispatcher.read().maybe_create_attacks(attacks);
            let mut attacks_ptr = self.get_attacks_ptr(key);
            attacks_ptr.clip_attack_slot_slots(hash, attack_ids.len());
            let (attribute, index) = key.into();
            for (slot, attack_id) in attack_ids.into_iter().enumerate() {
                let slot_id = (hash, slot).poseidon_hash();
                AttackSlotTable::set_entity(slot_id, @(attribute, index, slot, attack_id));
                attacks_ptr.write(slot_id, attack_id);
            }
            AbilityTable::set_entity(hash, @(attribute, index, name, abilities));
        }

        fn set_loadouts(ref self: ContractState, loadouts: Array<LoadoutInput>) {
            self.assert_caller_is_owner();
            let mut all_attacks: Array<IdTagAttack> = Default::default();
            let mut indexes: Array<
                (StorageBase<Mutable<Map<felt252, felt252>>>, BlobertAttribute, u32, felt252, u32),
            > =
                Default::default();
            for LoadoutInput { key, name, abilities, attacks } in loadouts {
                self.assert_caller_is_owner();
                let hash = key.poseidon_hash();

                let (mut abilities_ptr, mut attacks_ptr) = self.get_loadout_ptrs(key);
                abilities_ptr.write(hash, abilities);
                attacks_ptr.clip_attack_slot_slots(hash, attacks.len());
                let (attribute, index) = key.into();
                for (slot, attack) in attacks.into_iter().enumerate() {
                    all_attacks.append(attack);
                    indexes.append((attacks_ptr, attribute, index, hash, slot));
                }
                AbilityTable::set_entity(hash, @(attribute, index, name, abilities));
            }
            let attack_ids = self.attack_dispatcher.read().maybe_create_attacks(all_attacks);
            for (attack_id, (mut attacks_ptr, attribute, index, hash, slot)) in attack_ids
                .into_iter()
                .zip(indexes) {
                let slot_id = (hash, slot).poseidon_hash();
                AttackSlotTable::set_entity(slot_id, @(attribute, index, slot, attack_id));
                attacks_ptr.write(slot_id, attack_id);
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
            ref self: StorageBase<Mutable<Map<felt252, felt252>>>,
            key_hash: felt252,
            mut slots: u32,
        ) {
            loop {
                let slot_id = (key_hash, slots).poseidon_hash();
                if self.read(slot_id).is_non_zero() {
                    self.write(slot_id, 0);
                    slots += 1;
                } else {
                    break;
                }
            }
        }

        fn get_seed_attributes(self: @ContractState, hashes: Span<felt252>) -> Abilities {
            hashes.into_iter().map(|k| self.seed_abilities.read(*k)).sum()
        }

        fn get_seed_attack_slots(
            self: @ContractState, hashes: Span<felt252>, slots: Array<Array<felt252>>,
        ) -> Array<felt252> {
            slots
                .into_iter()
                .map(
                    |ks| {
                        let [key, slot]: [u32; 2] = ks.try_into().expect('Invalid slot format');
                        self.seed_attack_slots.read((*hashes[key], slot).poseidon_hash())
                    },
                )
                .collect()
        }

        fn get_custom_attack_slots(
            self: @ContractState, custom_id: u32, slots: Array<Array<felt252>>,
        ) -> Array<felt252> {
            slots
                .into_iter()
                .map(|slot| self.custom_attack_slots.read((custom_id, *slot[0]).poseidon_hash()))
                .collect()
        }

        fn get_attacks_ptr(
            ref self: ContractState, key: BlobertAttributeKey,
        ) -> StorageBase<Mutable<Map<felt252, felt252>>> {
            match key {
                BlobertAttributeKey::Custom(_) => self.custom_attack_slots,
                _ => self.seed_attack_slots,
            }
        }

        fn get_abilities_ptr(
            ref self: ContractState, key: BlobertAttributeKey,
        ) -> StorageBase<Mutable<Map<felt252, Abilities>>> {
            match key {
                BlobertAttributeKey::Custom(_) => self.custom_abilities,
                _ => self.seed_abilities,
            }
        }

        fn get_loadout_ptrs(
            ref self: ContractState, key: BlobertAttributeKey,
        ) -> (
            StorageBase<Mutable<Map<felt252, Abilities>>>,
            StorageBase<Mutable<Map<felt252, felt252>>>,
        ) {
            match key {
                BlobertAttributeKey::Custom(_) => (self.custom_abilities, self.custom_attack_slots),
                _ => (self.seed_abilities, self.seed_attack_slots),
            }
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

