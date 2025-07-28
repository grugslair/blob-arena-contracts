use ba_blobert::BlobertAttributeKey;
use crate::ability::Abilities;
use crate::attack::AttackWithName;

#[starknet::interface]
pub trait IArenaBlobertLoadout<TContractState> {
    fn set_attribute(
        ref self: TContractState,
        key: BlobertAttributeKey,
        abilities: Abilities,
        attacks: Array<AttackWithName>,
    );

    fn set_attributes(
        ref self: TContractState,
        keys_abilities_attacks: Array<(BlobertAttributeKey, Abilities, Array<AttackWithName>)>,
    );
}

#[derive(Drop, Serde, Introspect)]
struct AttackSlot {
    key: BlobertAttributeKey,
    slot: u32,
    attack: felt252,
}


#[derive(Drop, Serde, Introspect)]
struct BlobertAbilities {
    key: BlobertAttributeKey,
    strength: u32,
    vitality: u32,
    dexterity: u32,
    luck: u32,
}


#[starknet::contract]
mod arena_blobert_loadout {
    use ba_blobert::{BlobertAttributeKey, SeedTrait, TokenAttributes, get_blobert_attributes};
    use beacon_library::{ToriiTable, register_table_with_schema};
    use core::num::traits::Zero;
    use sai_access::{AccessTrait, access_component};
    use sai_core_utils::poseidon_serde::PoseidonSerde;
    use starknet::storage::{
        Map, Mutable, StorageBase, StorageMapReadAccess, StorageMapWriteAccess,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ClassHash, ContractAddress};
    use crate::ability::Abilities;
    use crate::attack::{AttackWithName, IAttackAdminDispatcher, IAttackAdminDispatcherTrait};
    use crate::interface::ILoadout;
    use super::{AttackSlot, IArenaBlobertLoadout};

    component!(path: access_component, storage: access, event: AccessEvents);

    const ABILITY_TABLE_ID: felt252 = bytearrays_hash!(
        "arena_blobert_loadout", "ArenaBlobertAbility",
    );
    const ATTACK_SLOT_TABLE_ID: felt252 = bytearrays_hash!(
        "arena_blobert_loadout", "ArenaBlobertAttackSlot",
    );

    impl AbilityTable = ToriiTable<ABILITY_TABLE_ID>;
    impl AttackSlotTable = ToriiTable<ATTACK_SLOT_TABLE_ID>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        access: access_component::Storage,
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
        AccessEvents: access_component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        collection_addresses: Array<ContractAddress>,
        attack_dispatcher_address: ContractAddress,
    ) {
        self.grant_owner(owner);
        for address in collection_addresses {
            self.collection_addresses.write(address, true);
        }
        self
            .attack_dispatcher
            .write(IAttackAdminDispatcher { contract_address: attack_dispatcher_address });
        register_table_with_schema::<Abilities>("arena_blobert_loadout", "ArenaBlobertAbility");
        register_table_with_schema::<AttackSlot>("arena_blobert_loadout", "ArenaBlobertAttackSlot");
    }

    #[abi(embed_v0)]
    impl ILoadoutImpl of ILoadout<ContractState> {
        fn abilities(
            self: @ContractState, collection_address: ContractAddress, token_id: u256,
        ) -> Abilities {
            self.assert_collection_address(collection_address);
            match get_blobert_attributes(collection_address, token_id) {
                TokenAttributes::Seed(seed) => self.get_seed_attributes(seed.key_hashes().span()),
                TokenAttributes::Custom(key) => self.custom_abilities.read(key),
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
                    self.custom_abilities.read(key), self.get_custom_attack_slots(key, slots),
                ),
            }
        }
    }

    #[abi(embed_v0)]
    impl IArenaBlobertLoadoutImpl of IArenaBlobertLoadout<ContractState> {
        fn set_attribute(
            ref self: ContractState,
            key: BlobertAttributeKey,
            abilities: Abilities,
            attacks: Array<AttackWithName>,
        ) {
            self.assert_caller_is_writer();
            let hash = key.poseidon_hash();
            self.get_abilities_ptr(key).write(hash, abilities);
            AbilityTable::set_entity(hash, @(key, abilities));
            let attack_ids = self.attack_dispatcher.read().create_attacks(attacks);
            let mut attacks_ptr = self.get_attacks_ptr(key);
            attacks_ptr.clip_attack_slot_slots(hash, attack_ids.len());
            for (slot, attack_id) in attack_ids.into_iter().enumerate() {
                let slot_id = (hash, slot).poseidon_hash();
                AttackSlotTable::set_entity(slot_id, @(key, slot, attack_id));
                attacks_ptr.write(slot_id, attack_id);
            }
        }

        fn set_attributes(
            ref self: ContractState,
            keys_abilities_attacks: Array<(BlobertAttributeKey, Abilities, Array<AttackWithName>)>,
        ) {
            self.assert_caller_is_writer();
            let mut all_attacks: Array<AttackWithName> = Default::default();
            let mut indexes: Array<
                (StorageBase<Mutable<Map<felt252, felt252>>>, BlobertAttributeKey, felt252, u32),
            > =
                Default::default();
            for (key, abilities, attacks) in keys_abilities_attacks {
                self.assert_caller_is_writer();
                let hash = key.poseidon_hash();
                AbilityTable::set_entity(hash, @(key, abilities));
                self.get_abilities_ptr(key).write(hash, abilities);
                let mut attacks_ptr = self.get_attacks_ptr(key);
                attacks_ptr.clip_attack_slot_slots(hash, attacks.len());
                for (slot, attack) in attacks.into_iter().enumerate() {
                    all_attacks.append(attack);
                    indexes.append((attacks_ptr, key, hash, slot));
                }
            }
            let attack_ids = self.attack_dispatcher.read().create_attacks(all_attacks);
            for (attack_id, (mut attacks_ptr, key, hash, slot)) in attack_ids
                .into_iter()
                .zip(indexes) {
                let slot_id = (hash, slot).poseidon_hash();
                AttackSlotTable::set_entity(slot_id, @(key, slot, attack_id));
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
            self: @ContractState, custom_id: felt252, slots: Array<Array<felt252>>,
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
// let (abilities_ptr, attacks_ptr) match key {
//                 BlobertAttributeKey::Custom(custom_id) => {
//                     self.custom_abilities.write(custom_id, abilities);
//                     let attack_ids = self.attack_dispatcher.read().create_attacks(attacks);
//                     AbilityEmitter::emit_entity(ref self, hash, @abilities);
//                     for (slot, attack_id) in attack_ids.into_iter().enumerate() {
//                         let slot_id = (hash, slot).poseidon_hash();
//                         AttackSlotEmitter::emit_entity(ref self, slot_id, @(key, slot,
//                         attack_id));
//                         self.custom_attack_slots.write(slot_id, attack_id);
//                     }
//                 },
//                 _ => {
//                     self.seed_abilities.write(key.poseidon_hash(), abilities);
//                     for attack in attacks {
//                         self
//                             .seed_attack_slots
//                             .write((key.poseidon_hash(), attack.slot).poseidon_hash(),
//                             attack.id);
//                     }
//                 },
//             }


