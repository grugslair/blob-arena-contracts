use crate::ability::Abilities;
use crate::attack::IdTagAttack;

#[starknet::interface]
pub trait IAmmaBlobertLoadout<TContractState> {
    fn set_fighter(
        ref self: TContractState, fighter: u32, abilities: Abilities, attacks: Array<IdTagAttack>,
    );

    fn set_fighters(
        ref self: TContractState,
        fighters_abilities_attacks: Array<(u32, Abilities, Array<IdTagAttack>)>,
    );
}

#[derive(Drop, Serde, Introspect)]
struct AttackSlot {
    fighter: u32,
    slot: u32,
    attack: felt252,
}

#[starknet::contract]
mod amma_blobert_loadout {
    use amma_blobert::get_fighter;
    use beacon_library::{ToriiTable, register_table_with_schema};
    use core::num::traits::Zero;
    use sai_access::{AccessTrait, access_component};
    use sai_core_utils::poseidon_serde::PoseidonSerde;
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use crate::ability::Abilities;
    use crate::attack::{IAttackAdminDispatcher, IAttackAdminDispatcherTrait, IdTagAttack};
    use crate::interface::ILoadout;
    use super::{AttackSlot, IAmmaBlobertLoadout};

    component!(path: access_component, storage: access, event: AccessEvents);

    const ABILITY_TABLE_ID: felt252 = bytearrays_hash!(
        "amma_blobert_loadout", "AmmaBlobertAbility",
    );
    const ATTACK_SLOT_TABLE_ID: felt252 = bytearrays_hash!(
        "amma_blobert_loadout", "AmmaBlobertAttackSlot",
    );

    impl AbilityTable = ToriiTable<ABILITY_TABLE_ID>;
    impl AttackSlotTable = ToriiTable<ATTACK_SLOT_TABLE_ID>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        access: access_component::Storage,
        collection_address: ContractAddress,
        attack_dispatcher: IAttackAdminDispatcher,
        attack_slots: Map<felt252, felt252>,
        abilities: Map<u32, Abilities>,
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
        attack_dispatcher_address: ContractAddress,
        collection_address: ContractAddress,
    ) {
        self.grant_owner(owner);
        self.collection_address.write(collection_address);
        self
            .attack_dispatcher
            .write(IAttackAdminDispatcher { contract_address: attack_dispatcher_address });
        register_table_with_schema::<Abilities>("amma_blobert_loadout", "AmmaBlobertAbility");
        register_table_with_schema::<AttackSlot>("amma_blobert_loadout", "AmmaBlobertAttackSlot");
    }

    #[abi(embed_v0)]
    impl IAccessImpl = access_component::AccessImpl<ContractState>;

    #[abi(embed_v0)]
    impl ILoadoutImpl of ILoadout<ContractState> {
        fn abilities(
            self: @ContractState, collection_address: ContractAddress, token_id: u256,
        ) -> Abilities {
            assert(
                self.collection_address.read() == collection_address, 'Invalid collection address',
            );
            self.abilities.read(get_fighter(collection_address, token_id))
        }
        fn attacks(
            self: @ContractState,
            collection_address: ContractAddress,
            token_id: u256,
            slots: Array<Array<felt252>>,
        ) -> Array<felt252> {
            assert(
                self.collection_address.read() == collection_address, 'Invalid collection address',
            );
            let fighter = get_fighter(collection_address, token_id);
            let mut attack_ids: Array<felt252> = Default::default();
            for slot in slots {
                attack_ids.append(self.attack_slots.read((fighter, *slot[0]).poseidon_hash()));
            }
            attack_ids
        }
        fn loadout(
            self: @ContractState,
            collection_address: ContractAddress,
            token_id: u256,
            slots: Array<Array<felt252>>,
        ) -> (Abilities, Array<felt252>) {
            assert(
                self.collection_address.read() == collection_address, 'Invalid collection address',
            );
            let fighter = get_fighter(collection_address, token_id);
            let abilities = self.abilities.read(fighter);
            let mut attack_ids: Array<felt252> = Default::default();
            for slot in slots {
                attack_ids.append(self.attack_slots.read((fighter, *slot[0]).poseidon_hash()));
            }
            (abilities, attack_ids)
        }
    }

    #[abi(embed_v0)]
    impl IAmmaBlobertLoadoutImpl of IAmmaBlobertLoadout<ContractState> {
        fn set_fighter(
            ref self: ContractState,
            fighter: u32,
            abilities: Abilities,
            attacks: Array<IdTagAttack>,
        ) {
            self.assert_caller_is_writer();
            assert(fighter > 0, 'Fighter must be greater than 0');
            let mut attack_dispatcher = self.attack_dispatcher.read();
            let attack_ids = attack_dispatcher.maybe_create_attacks(attacks);
            self.abilities.write(fighter, abilities);
            AbilityTable::set_entity(fighter, @abilities);
            self.clip_attack_slot_slots(fighter, attack_ids.len());
            for (slot, attack_id) in attack_ids.into_iter().enumerate() {
                let slot_id = (fighter, slot).poseidon_hash();
                AttackSlotTable::set_entity(slot_id, @(fighter, slot, attack_id));
                self.attack_slots.write(slot_id, attack_id);
            }
        }

        fn set_fighters(
            ref self: ContractState,
            fighters_abilities_attacks: Array<(u32, Abilities, Array<IdTagAttack>)>,
        ) {
            self.assert_caller_is_writer();
            let mut all_attacks: Array<IdTagAttack> = Default::default();
            let mut indexes: Array<(u32, u32)> = Default::default();
            for (fighter, abilities, attacks) in fighters_abilities_attacks {
                self.abilities.write(fighter, abilities);
                AbilityTable::set_entity(fighter, @abilities);
                self.clip_attack_slot_slots(fighter, attacks.len());
                for (i, attack) in attacks.into_iter().enumerate() {
                    all_attacks.append(attack);
                    indexes.append((fighter, i));
                }
            }
            let mut attack_dispatcher = self.attack_dispatcher.read();
            let attack_ids = attack_dispatcher.maybe_create_attacks(all_attacks);
            for (attack_id, (fighter, slot)) in attack_ids.into_iter().zip(indexes) {
                let slot_id = (fighter, slot).poseidon_hash();
                AttackSlotTable::set_entity(slot_id, @(fighter, slot, attack_id));
                self.attack_slots.write(slot_id, attack_id);
            }
        }
    }

    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn clip_attack_slot_slots(ref self: ContractState, fighter: u32, mut slots: u32) {
            loop {
                let slot_id = (fighter, slots).poseidon_hash();
                if self.attack_slots.read(slot_id).is_non_zero() {
                    self.attack_slots.write(slot_id, 0);
                    slots += 1;
                } else {
                    break;
                }
            }
        }
    }
}
