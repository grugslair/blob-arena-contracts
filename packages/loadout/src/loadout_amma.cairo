use starknet::ContractAddress;
use crate::action::IdTagAction;
use crate::attributes::Attributes;

#[derive(Drop, Serde)]
struct FighterInput {
    attributes: Attributes,
    actions: Array<IdTagAction>,
}

#[starknet::interface]
pub trait IAmmaLoadout<TContractState> {
    fn set_fighter(
        ref self: TContractState, fighter: u32, attributes: Attributes, actions: Array<IdTagAction>,
    );

    fn add_fighter(
        ref self: TContractState, attributes: Attributes, actions: Array<IdTagAction>,
    ) -> u32;

    fn set_fighters(ref self: TContractState, fighters: Array<FighterInput>);

    fn add_fighters(ref self: TContractState, fighters: Array<FighterInput>) -> Array<u32>;

    fn fighter_count(self: @TContractState) -> u32;

    fn fighter_attributes(self: @TContractState, fighter: u32) -> Attributes;

    fn fighter_actions(
        self: @TContractState, fighter: u32, slots: Array<Array<felt252>>,
    ) -> Array<felt252>;

    fn fighter_loadout(
        self: @TContractState, fighter: u32, slots: Array<Array<felt252>>,
    ) -> (Attributes, Array<felt252>);
}

pub fn get_fighter_loadout(
    contract_address: ContractAddress, fighter: u32, slots: Array<Array<felt252>>,
) -> (Attributes, Array<felt252>) {
    IAmmaLoadoutDispatcher { contract_address }.fighter_loadout(fighter, slots)
}

pub fn get_fighter_actions(
    contract_address: ContractAddress, fighter: u32, slots: Array<Array<felt252>>,
) -> Array<felt252> {
    IAmmaLoadoutDispatcher { contract_address }.fighter_actions(fighter, slots)
}

pub fn get_fighter_count(contract_address: ContractAddress) -> u32 {
    IAmmaLoadoutDispatcher { contract_address }.fighter_count()
}

#[derive(Drop, Serde, Introspect)]
struct ActionSlot {
    fighter: u32,
    slot: u32,
    action: felt252,
}

#[starknet::contract]
mod loadout_amma {
    use amma_blobert::get_fighter;
    use beacon_library::{ToriiTable, register_table_with_schema};
    use core::num::traits::Zero;
    use sai_core_utils::poseidon_serde::PoseidonSerde;
    use sai_ownable::{OwnableTrait, ownable_component};
    use sai_packing::shifts::SHIFT_4B_FELT252;
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use crate::action::{IActionAdminDispatcher, IActionAdminDispatcherTrait, IdTagAction};
    use crate::interface::ILoadout;
    use super::{ActionSlot, Attributes, FighterInput, IAmmaLoadout};

    component!(path: ownable_component, storage: ownable, event: OwnableEvents);

    const ABILITY_TABLE_ID: felt252 = bytearrays_hash!("loadout_amma", "Attributes");
    const ATTACK_SLOT_TABLE_ID: felt252 = bytearrays_hash!("loadout_amma", "ActionSlots");

    impl AbilityTable = ToriiTable<ABILITY_TABLE_ID>;
    impl ActionSlotTable = ToriiTable<ATTACK_SLOT_TABLE_ID>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: ownable_component::Storage,
        collection_addresses: Map<ContractAddress, bool>,
        attributes: Map<u32, Attributes>,
        action_dispatcher: IActionAdminDispatcher,
        action_slots: Map<felt252, felt252>,
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
        action_dispatcher_address: ContractAddress,
        collection_addresses: Array<ContractAddress>,
    ) {
        self.grant_owner(owner);
        for address in collection_addresses {
            self.collection_addresses.write(address, true);
        }
        self
            .action_dispatcher
            .write(IActionAdminDispatcher { contract_address: action_dispatcher_address });
        register_table_with_schema::<Attributes>("loadout_amma", "Attributes");
        register_table_with_schema::<ActionSlot>("loadout_amma", "ActionSlots");
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
        fn actions(
            self: @ContractState,
            collection_address: ContractAddress,
            token_id: u256,
            slots: Array<Array<felt252>>,
        ) -> Array<felt252> {
            self.fighter_actions(self.fighter(collection_address, token_id), slots)
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
            actions: Array<IdTagAction>,
        ) {
            self.assert_caller_is_owner();
            assert(fighter > 0, 'Fighter must be greater than 0');
            assert(fighter <= self.count.read(), 'Fighter does not exist');
            let mut action_dispatcher = self.action_dispatcher.read();
            let action_ids = action_dispatcher.maybe_create_actions(actions);
            self.set_fighter_internal(fighter, attributes, action_ids);
        }

        fn add_fighter(
            ref self: ContractState, attributes: Attributes, actions: Array<IdTagAction>,
        ) -> u32 {
            self.assert_caller_is_owner();
            let fighter = self.count.read() + 1;
            let mut action_dispatcher = self.action_dispatcher.read();
            let action_ids = action_dispatcher.maybe_create_actions(actions);
            self.set_fighter_internal(fighter, attributes, action_ids);
            self.count.write(fighter);
            fighter
        }

        fn set_fighters(ref self: ContractState, fighters: Array<FighterInput>) {
            self.assert_caller_is_owner();
            self.set_fighters_internal(self.count.read(), fighters);
        }

        fn add_fighters(ref self: ContractState, fighters: Array<FighterInput>) -> Array<u32> {
            self.assert_caller_is_owner();
            let count = self.count.read();
            self.set_fighters_internal(count, fighters)
        }


        fn fighter_count(self: @ContractState) -> u32 {
            self.count.read()
        }

        fn fighter_attributes(self: @ContractState, fighter: u32) -> Attributes {
            self.check_fighter(fighter);
            self.fighter_attributes_internal(fighter)
        }
        fn fighter_actions(
            self: @ContractState, fighter: u32, slots: Array<Array<felt252>>,
        ) -> Array<felt252> {
            self.check_fighter(fighter);
            self.fighter_actions_internal(fighter, slots)
        }

        fn fighter_loadout(
            self: @ContractState, fighter: u32, slots: Array<Array<felt252>>,
        ) -> (Attributes, Array<felt252>) {
            self.check_fighter(fighter);
            (
                self.fighter_attributes_internal(fighter),
                self.fighter_actions_internal(fighter, slots),
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
        fn clip_action_slot_slots(ref self: ContractState, index: felt252, slots: u32) {
            let mut slots: felt252 = slots.into();
            let mut slot_ids: Array<felt252> = Default::default();

            loop {
                let slot_id = index + slots.into();
                if self.action_slots.read(slot_id).is_non_zero() {
                    self.action_slots.write(slot_id, 0);
                    slot_ids.append(slot_id);
                    slots += 1;
                } else {
                    break;
                }
            }
            ActionSlotTable::delete_entities(slot_ids);
        }

        fn set_fighter_internal(
            ref self: ContractState, fighter: u32, attributes: Attributes, actions: Array<felt252>,
        ) {
            AbilityTable::set_entity(fighter, @attributes);
            self.attributes.write(fighter, attributes);
            let slot_index: felt252 = fighter.into() * SHIFT_4B_FELT252;
            self.clip_action_slot_slots(slot_index, actions.len());
            for (n, action_id) in actions.into_iter().enumerate() {
                let slot_id = slot_index + n.into();
                ActionSlotTable::set_entity(slot_id, @(fighter, n, action_id));
                self.action_slots.write(slot_id, action_id);
            }
        }

        fn set_fighters_internal(
            ref self: ContractState, starting_count: u32, fighters: Array<FighterInput>,
        ) -> Array<u32> {
            let mut all_actions: Array<Array<IdTagAction>> = Default::default();
            let mut all_fighters: Array<Attributes> = Default::default();
            self.count.write(fighters.len() + starting_count);
            for FighterInput { attributes, actions } in fighters {
                all_actions.append(actions);
                all_fighters.append(attributes);
            }
            let action_dispatcher = self.action_dispatcher.read();
            let all_action_ids = action_dispatcher.maybe_create_actions_array(all_actions);
            let mut ids: Array<u32> = Default::default();
            for (i, (attributes, actions)) in all_fighters
                .into_iter()
                .zip(all_action_ids)
                .enumerate() {
                let id = i + starting_count + 1;
                ids.append(id);
                self.set_fighter_internal(id, attributes, actions);
            }
            ids
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

        fn fighter_actions_internal(
            self: @ContractState, fighter: u32, slots: Array<Array<felt252>>,
        ) -> Array<felt252> {
            let slot_index: felt252 = fighter.into() * SHIFT_4B_FELT252;
            slots.into_iter().map(|s| self.action_slots.read(slot_index + *s[0])).collect()
        }
    }
}
