use starknet::ContractAddress;
use crate::attack::IdTagAttack;
use crate::attributes::{Attributes, PartialAttributes};

#[derive(Drop, Serde)]
struct FighterInput {
    fighter: u32,
    attributes: Attributes,
    gen_attributes: PartialAttributes,
    attacks: Array<IdTagAttack>,
}

#[starknet::interface]
pub trait IAmmaLoadout<TContractState> {
    fn set_fighter(
        ref self: TContractState,
        fighter: u32,
        attributes: Attributes,
        gen_attributes: PartialAttributes,
        attacks: Array<IdTagAttack>,
    );

    fn set_fighters(ref self: TContractState, fighters: Array<FighterInput>);

    fn set_fighter_count(ref self: TContractState, count: u32);

    fn fighter_count(self: @TContractState) -> u32;

    fn fighter_attributes(self: @TContractState, fighter: u32) -> Attributes;

    fn fighter_attacks(
        self: @TContractState, fighter: u32, slots: Array<Array<felt252>>,
    ) -> Array<felt252>;

    fn fighter_loadout(
        self: @TContractState, fighter: u32, slots: Array<Array<felt252>>,
    ) -> (Attributes, Array<felt252>);

    fn fighter_gen_attributes(self: @TContractState, fighter: u32) -> PartialAttributes;

    fn fighter_gen_loadout(
        self: @TContractState, fighter: u32, slots: Array<Array<felt252>>,
    ) -> (PartialAttributes, Array<felt252>);
}

pub fn get_fighter_loadout(
    contract_address: ContractAddress, fighter: u32, slots: Array<Array<felt252>>,
) -> (Attributes, Array<felt252>) {
    IAmmaLoadoutDispatcher { contract_address }.fighter_loadout(fighter, slots)
}

pub fn get_fighter_gen_loadout(
    contract_address: ContractAddress, fighter: u32, slots: Array<Array<felt252>>,
) -> (PartialAttributes, Array<felt252>) {
    IAmmaLoadoutDispatcher { contract_address }.fighter_gen_loadout(fighter, slots)
}

pub fn get_fighter_attacks(
    contract_address: ContractAddress, fighter: u32, slots: Array<Array<felt252>>,
) -> Array<felt252> {
    IAmmaLoadoutDispatcher { contract_address }.fighter_attacks(fighter, slots)
}

pub fn get_fighter_count(contract_address: ContractAddress) -> u32 {
    IAmmaLoadoutDispatcher { contract_address }.fighter_count()
}

#[derive(Drop, Serde, Introspect)]
struct AttackSlot {
    fighter: u32,
    slot: u32,
    attack: felt252,
}

#[derive(Drop, Serde, Introspect)]
struct FighterAttributes {
    attributes: Attributes,
    gen_attributes: PartialAttributes,
}

#[starknet::contract]
mod loadout_amma {
    use amma_blobert::get_fighter;
    use beacon_library::{ToriiTable, register_table_with_schema};
    use core::num::traits::Zero;
    use sai_core_utils::poseidon_serde::PoseidonSerde;
    use sai_ownable::{OwnableTrait, ownable_component};
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use crate::attack::{IAttackAdminDispatcher, IAttackAdminDispatcherTrait, IdTagAttack};
    use crate::interface::ILoadout;
    use super::{
        AttackSlot, Attributes, FighterAttributes, FighterInput, IAmmaLoadout, PartialAttributes,
    };

    component!(path: ownable_component, storage: ownable, event: OwnableEvents);

    const ABILITY_TABLE_ID: felt252 = bytearrays_hash!("loadout_amma", "AmmaAbility");
    const ATTACK_SLOT_TABLE_ID: felt252 = bytearrays_hash!("loadout_amma", "AmmaAttackSlot");

    impl AbilityTable = ToriiTable<ABILITY_TABLE_ID>;
    impl AttackSlotTable = ToriiTable<ATTACK_SLOT_TABLE_ID>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: ownable_component::Storage,
        collection_addresses: Map<ContractAddress, bool>,
        attack_dispatcher: IAttackAdminDispatcher,
        attack_slots: Map<felt252, felt252>,
        base_attributes: Map<u32, PartialAttributes>,
        level_attributes: Map<u32, PartialAttributes>,
        count: u32,
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
        register_table_with_schema::<FighterAttributes>("loadout_amma", "Attributes");
        register_table_with_schema::<AttackSlot>("loadout_amma", "AttackSlots");
    }

    #[abi(embed_v0)]
    impl IOwnableImpl = ownable_component::OwnableImpl<ContractState>;

    #[abi(embed_v0)]
    impl ILoadoutImpl of ILoadout<ContractState> {
        fn attributes(
            self: @ContractState, collection_address: ContractAddress, token_id: u256,
        ) -> Attributes {
            self.fighter_attributes(self.fighter(collection_address, token_id))
        }
        fn attacks(
            self: @ContractState,
            collection_address: ContractAddress,
            token_id: u256,
            slots: Array<Array<felt252>>,
        ) -> Array<felt252> {
            self.fighter_attacks(self.fighter(collection_address, token_id), slots)
        }
        fn loadout(
            self: @ContractState,
            collection_address: ContractAddress,
            token_id: u256,
            slots: Array<Array<felt252>>,
        ) -> (Attributes, Array<felt252>) {
            self.fighter_loadout(self.fighter(collection_address, token_id), slots)
        }
    }

    #[abi(embed_v0)]
    impl IAmmaLoadoutImpl of IAmmaLoadout<ContractState> {
        fn set_fighter(
            ref self: ContractState,
            fighter: u32,
            attributes: Attributes,
            gen_attributes: DAttributes,
            attacks: Array<IdTagAttack>,
        ) {
            self.assert_caller_is_owner();
            assert(fighter > 0, 'Fighter must be greater than 0');
            let mut attack_dispatcher = self.attack_dispatcher.read();
            let attack_ids = attack_dispatcher.maybe_create_attacks(attacks);
            self.attributes.write(fighter, attributes);
            self.gen_attributes.write(fighter, gen_attributes);
            AbilityTable::set_entity(fighter, @(attributes, gen_attributes));
            self.clip_attack_slot_slots(fighter, attack_ids.len());

            for (slot, attack_id) in attack_ids.into_iter().enumerate() {
                let slot_id = (fighter, slot).poseidon_hash();
                AttackSlotTable::set_entity(slot_id, @(fighter, slot, attack_id));
                self.attack_slots.write(slot_id, attack_id);
            }
        }

        fn set_fighters(ref self: ContractState, fighters: Array<FighterInput>) {
            self.assert_caller_is_owner();
            let mut all_attacks: Array<IdTagAttack> = Default::default();
            let mut indexes: Array<(u32, u32)> = Default::default();
            for FighterInput { fighter, attributes, attacks, gen_attributes } in fighters {
                self.attributes.write(fighter, attributes);
                self.gen_attributes.write(fighter, gen_attributes);
                AbilityTable::set_entity(fighter, @(attributes, gen_attributes));
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

        fn set_fighter_count(ref self: ContractState, count: u32) {
            self.assert_caller_is_owner();
            let current_count = self.count.read();
            assert(count >= current_count, 'Fighter count cannot decrease');
            if count > current_count {
                self.count.write(count);
            }
        }

        fn fighter_count(self: @ContractState) -> u32 {
            self.count.read()
        }

        fn fighter_attributes(self: @ContractState, fighter: u32) -> Attributes {
            self.check_fighter(fighter);
            self.fighter_attributes_internal(fighter)
        }

        fn fighter_gen_attributes(self: @ContractState, fighter: u32) -> DAttributes {
            self.check_fighter(fighter);
            self.fighter_gen_attributes_internal(fighter)
        }

        fn fighter_attacks(
            self: @ContractState, fighter: u32, slots: Array<Array<felt252>>,
        ) -> Array<felt252> {
            self.check_fighter(fighter);
            self.fighter_attacks_internal(fighter, slots)
        }

        fn fighter_loadout(
            self: @ContractState, fighter: u32, slots: Array<Array<felt252>>,
        ) -> (Attributes, Array<felt252>) {
            self.check_fighter(fighter);
            (
                self.fighter_attributes_internal(fighter),
                self.fighter_attacks_internal(fighter, slots),
            )
        }

        fn fighter_gen_loadout(
            self: @ContractState, fighter: u32, slots: Array<Array<felt252>>,
        ) -> (DAttributes, Array<felt252>) {
            self.check_fighter(fighter);
            (
                self.fighter_gen_attributes_internal(fighter),
                self.fighter_attacks_internal(fighter, slots),
            )
        }
    }

    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn assert_collection_address(self: @ContractState, collection_address: ContractAddress) {
            assert(
                self.collection_addresses.read(collection_address), 'Invalid collection address',
            );
        }
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

        fn fighter(
            self: @ContractState, collection_address: ContractAddress, token_id: u256,
        ) -> u32 {
            self.assert_collection_address(collection_address);
            assert(token_id.is_non_zero(), 'Invalid token ID');
            get_fighter(collection_address, token_id)
        }

        fn check_fighter(self: @ContractState, fighter: u32) {
            assert(fighter.is_non_zero() && fighter <= self.count.read(), 'Invalid fighter');
        }

        fn fighter_attributes_internal(self: @ContractState, fighter: u32) -> Attributes {
            self.attributes.read(fighter)
        }

        fn fighter_gen_attributes_internal(self: @ContractState, fighter: u32) -> DAttributes {
            self.gen_attributes.read(fighter)
        }

        fn fighter_attacks_internal(
            self: @ContractState, fighter: u32, slots: Array<Array<felt252>>,
        ) -> Array<felt252> {
            slots
                .into_iter()
                .map(|s| self.attack_slots.read((fighter, *s[0]).poseidon_hash()))
                .collect()
        }
    }
}
