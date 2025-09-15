use ba_blobert::BlobertTrait;
use crate::ability::DAbilities;
use crate::attack::IdTagAttack;

#[starknet::interface]
pub trait IClassicLoadout<TContractState> {
    fn set_loadout(
        ref self: TContractState,
        blobert_trait: BlobertTrait,
        index: u32,
        name: ByteArray,
        abilities: DAbilities,
        attacks: Array<IdTagAttack>,
    );

    fn set_loadouts(ref self: TContractState, loadouts: Array<LoadoutInput>);
}

#[derive(Drop, Serde)]
struct LoadoutInput {
    blobert_trait: BlobertTrait,
    index: u32,
    name: ByteArray,
    abilities: DAbilities,
    attacks: Array<IdTagAttack>,
}

#[derive(Drop, Serde, Introspect)]
struct AttackSlot {
    blobert_trait: BlobertTrait,
    index: u32,
    slot: u32,
    attack: felt252,
}


#[derive(Drop, Serde, Introspect)]
struct BlobertAbilities {
    blobert_trait: BlobertTrait,
    index: u32,
    name: ByteArray,
    strength: u16,
    vitality: u16,
    dexterity: u16,
    luck: u16,
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
    use sai_packing::SHIFT_4B;
    use sai_packing::byte::SHIFT_4B_FELT252;
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, Mutable, StorageBase, StorageMapReadAccess, StorageMapWriteAccess,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use crate::ability::{Abilities, AbilitiesTrait, DAbilities};
    use crate::attack::{IAttackAdminDispatcher, IAttackAdminDispatcherTrait};
    use crate::interface::ILoadout;
    use super::{AttackSlot, BlobertAbilities, IClassicLoadout, IdTagAttack, LoadoutInput};

    component!(path: ownable_component, storage: ownable, event: OwnableEvents);

    const ABILITY_TABLE_ID: felt252 = bytearrays_hash!("loadout_classic", "ClassicAbility");
    const ATTACK_SLOT_TABLE_ID: felt252 = bytearrays_hash!("loadout_classic", "ClassicAttackSlot");

    impl AbilityTable = ToriiTable<ABILITY_TABLE_ID>;
    impl AttackSlotTable = ToriiTable<ATTACK_SLOT_TABLE_ID>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: ownable_component::Storage,
        collection_addresses: Map<ContractAddress, bool>,
        attack_dispatcher: IAttackAdminDispatcher,
        abilities: Map<felt252, DAbilities>,
        attack_slots: Map<felt252, felt252>,
        base_stats: Abilities,
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
        register_table_with_schema::<BlobertAbilities>("loadout_classic", "ClassicAbility");
        register_table_with_schema::<AttackSlot>("loadout_classic", "ClassicAttackSlot");
    }

    #[abi(embed_v0)]
    impl IOwnableImpl = ownable_component::OwnableImpl<ContractState>;

    #[abi(embed_v0)]
    impl ILoadoutImpl of ILoadout<ContractState> {
        fn abilities(
            self: @ContractState, collection_address: ContractAddress, token_id: u256,
        ) -> Abilities {
            self.assert_collection_address(collection_address);
            let dabilities = match get_blobert_traits(collection_address, token_id) {
                TokenTraits::Seed(seed) => self.get_seed_traits(seed.indexes()),
                TokenTraits::Custom(index) => self.abilities.read(get_custom_index(index)),
            };
            self.base_stats.read().add_d_abilities(dabilities)
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
        ) -> (Abilities, Array<felt252>) {
            self.assert_collection_address(collection_address);
            let (abilities, attack_slots) = match get_blobert_traits(collection_address, token_id) {
                TokenTraits::Seed(seed) => {
                    let indexes = seed.indexes();
                    (self.get_seed_traits(indexes), self.get_seed_attack_slots(indexes, slots))
                },
                TokenTraits::Custom(index) => {
                    let aindex = get_custom_index(index);
                    (self.abilities.read(aindex), self.get_custom_attack_slots(aindex, slots))
                },
            };
            (self.base_stats.read().add_d_abilities(abilities), attack_slots)
        }
    }

    #[abi(embed_v0)]
    impl IClassicLoadoutImpl of IClassicLoadout<ContractState> {
        fn set_loadout(
            ref self: ContractState,
            blobert_trait: BlobertTrait,
            index: u32,
            name: ByteArray,
            abilities: DAbilities,
            attacks: Array<IdTagAttack>,
        ) {
            self.assert_caller_is_owner();
            let abilities_index = blobert_trait.index(index);
            self.abilities.write(abilities_index, abilities);

            let attack_ids = self.attack_dispatcher.read().maybe_create_attacks(attacks);
            let mut attacks_ptr = self.attack_slots;
            let attack_slot_index = abilities_index * SHIFT_4B_FELT252;
            attacks_ptr.clip_attack_slot_slots(attack_slot_index, attack_ids.len());
            for (slot, attack_id) in attack_ids.into_iter().enumerate() {
                let slot_id = attack_slot_index + slot.into();
                AttackSlotTable::set_entity(slot_id, @(blobert_trait, index, slot, attack_id));
                attacks_ptr.write(slot_id, attack_id);
            }
            AbilityTable::set_entity(abilities_index, @(blobert_trait, index, name, abilities));
        }


        fn set_loadouts(ref self: ContractState, loadouts: Array<LoadoutInput>) {
            self.assert_caller_is_owner();
            let mut all_attacks: Array<IdTagAttack> = Default::default();
            let mut indexes: Array<(BlobertTrait, u32, felt252, u32)> = Default::default();
            let mut attacks_ptr = self.attack_slots;
            let mut abilities_ptr = self.abilities;

            for LoadoutInput { blobert_trait, index, name, abilities, attacks } in loadouts {
                self.assert_caller_is_owner();
                let abilities_index = blobert_trait.index(index);

                abilities_ptr.write(abilities_index, abilities);
                let slot_index = abilities_index * SHIFT_4B.into();
                attacks_ptr.clip_attack_slot_slots(slot_index, attacks.len());
                AbilityTable::set_entity(abilities_index, @(blobert_trait, index, name, abilities));
                for (slot, attack) in attacks.into_iter().enumerate() {
                    all_attacks.append(attack);
                    indexes.append((blobert_trait, index, slot_index, slot));
                }
            }
            let attack_ids = self.attack_dispatcher.read().maybe_create_attacks(all_attacks);
            for (attack_id, (blobert_trait, index, slot_index, slot)) in attack_ids
                .into_iter()
                .zip(indexes) {
                let slot_id = slot_index + slot.into();
                AttackSlotTable::set_entity(slot_id, @(blobert_trait, index, slot, attack_id));
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
            ref self: StorageBase<Mutable<Map<felt252, felt252>>>, hash: felt252, mut slots: u32,
        ) {
            loop {
                let slot_id = hash + slots.into();
                if self.read(slot_id).is_non_zero() {
                    self.write(slot_id, 0);
                    slots += 1;
                } else {
                    break;
                }
            }
        }

        fn get_seed_traits(self: @ContractState, indexes: Span<felt252>) -> DAbilities {
            indexes.into_iter().map(|k| self.abilities.read(*k)).sum()
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
        // fn get_loadout_ptrs(
    //     ref self: ContractState, key: BlobertTraitKey,
    // ) -> (
    //     StorageBase<Mutable<Map<felt252, Abilities>>>,
    //     StorageBase<Mutable<Map<felt252, felt252>>>,
    // ) {
    //     match key {
    //         BlobertTraitKey::Custom(_) => (self.custom_abilities,
    //         self.custom_attack_slots), _ => (self.seed_abilities, self.seed_attack_slots),
    //     }
    // }
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

