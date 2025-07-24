use ba_blobert::BlobertAttributeKey;
use crate::ability::Abilities;
use crate::attack::AttackWithName;

#[starknet::interface]
pub trait IArenaBlobertLoadout<TContractState> {
    fn set_seed_attribute(
        ref self: TContractState,
        fighter: BlobertAttributeKey,
        abilities: Abilities,
        attacks: Array<AttackWithName>,
    );

    fn set_seed_attributes(
        ref self: TContractState,
        fighters_abilities_attacks: Array<(BlobertAttributeKey, Abilities, Array<AttackWithName>)>,
    );
}

#[beacon_entity]
#[derive(Drop, Serde, Introspect)]
struct AttackSlot {
    fighter: u32,
    slot: u32,
    attack: felt252,
}

#[starknet::contract]
mod arena_blobert_loadout {
    use ba_blobert::{BlobertAttributeKey, Seed, SeedTrait, TokenAttributes, get_blobert_attributes};
    use core::num::traits::Zero;
    use sai_access::{AccessTrait, access_component};
    use sai_core_utils::poseidon_serde::PoseidonSerde;
    use starknet::storage::{
        Map, Mutable, StorageBase, StorageMapReadAccess, StorageMapWriteAccess,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ClassHash, ContractAddress};
    use torii_beacon::emitter::{ToriiRegistryEmitter, const_entity};
    use torii_beacon::emitter_component;
    use crate::ability::Abilities;
    use crate::attack::{AttackWithName, IAttackAdminDispatcher, IAttackAdminDispatcherTrait};
    use crate::interface::ILoadout;
    use super::IArenaBlobertLoadout;

    component!(path: emitter_component, storage: emitter, event: EmitterEvents);
    component!(path: access_component, storage: access, event: AccessEvents);

    const ABILITY_TABLE_ID: felt252 = bytearrays_hash!(
        "arena_blobert_loadout", "ArenaBlobertAbility",
    );
    const ATTACK_SLOT_TABLE_ID: felt252 = bytearrays_hash!(
        "arena_blobert_loadout", "ArenaBlobertAttackSlot",
    );
    impl AbilityEmitter = const_entity::ConstEntityEmitter<ABILITY_TABLE_ID, ContractState>;
    impl AttackSlotEmitter = const_entity::ConstEntityEmitter<ATTACK_SLOT_TABLE_ID, ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        emitter: emitter_component::Storage,
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
        EmitterEvents: emitter_component::Event,
        #[flat]
        AccessEvents: access_component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        collection_addresses: Array<ContractAddress>,
        attack_dispatcher_address: ContractAddress,
        blobert_ability_class_hash: ClassHash,
        blobert_attack_slot_class_hash: ClassHash,
    ) {
        self.grant_owner(owner);
        for address in collection_addresses {
            self.collection_addresses.write(address, true);
        }
        self
            .attack_dispatcher
            .write(IAttackAdminDispatcher { contract_address: attack_dispatcher_address });
        self
            .emit_register_entity(
                "arena_blobert_loadout", "ArenaBlobertAbility", blobert_ability_class_hash,
            );
        self
            .emit_register_entity(
                "arena_blobert_loadout", "ArenaBlobertAttackSlot", blobert_attack_slot_class_hash,
            );
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

