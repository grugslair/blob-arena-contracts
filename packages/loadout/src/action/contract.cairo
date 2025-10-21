#[starknet::contract]
mod action {
    use ba_utils::storage::ShortArrayStore;
    use beacon_library::{ToriiTable, register_table};
    use core::num::traits::Zero;
    use sai_access::{AccessTrait, access_component};
    use sai_core_utils::poseidon_serde::PoseidonSerde;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::storage_access::StorePacking;
    use starknet::{ClassHash, ContractAddress};
    use crate::action::action::{
        EffectArrayStorageMapReadAccess, EffectArrayStorageMapWriteAccess, byte_array_to_tag,
    };
    use crate::action::effect::EffectArrayStorePacking;
    use crate::action::{
        Action, ActionWithName, ActionWithNameTrait, Effect, IAction, IActionAdmin, IdTagAction,
        get_action_id,
    };

    component!(path: access_component, storage: access, event: AccessEvents);

    const ATTACK_TABLE_ID: felt252 = bytearrays_hash!("action", "Action");
    impl ActionTable = ToriiTable<ATTACK_TABLE_ID>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        access: access_component::Storage,
        speeds: Map<felt252, u16>,
        chances: Map<felt252, u8>,
        cooldowns: Map<felt252, u32>,
        successes: Map<felt252, Array<felt252>>,
        fails: Map<felt252, Array<felt252>>,
        tags: Map<felt252, felt252>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccessEvents: access_component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, owner: ContractAddress, action_model_class_hash: ClassHash,
    ) {
        self.grant_owner(owner);
        register_table("action", "Action", action_model_class_hash);
    }

    #[abi(embed_v0)]
    impl IAccessImpl = access_component::AccessImpl<ContractState>;

    #[abi(embed_v0)]
    impl IActionImpl of IAction<ContractState> {
        fn action(self: @ContractState, id: felt252) -> Action {
            Action {
                speed: self.speeds.read(id),
                chance: self.chances.read(id),
                cooldown: self.cooldowns.read(id),
                success: StorePacking::unpack(self.successes.read(id)),
                fail: StorePacking::unpack(self.fails.read(id)),
            }
        }

        fn actions(self: @ContractState, ids: Array<felt252>) -> Array<Action> {
            ids.into_iter().map(|id| self.action(id)).collect()
        }

        fn speed(self: @ContractState, id: felt252) -> u16 {
            self.speeds.read(id)
        }

        fn speeds(self: @ContractState, ids: Array<felt252>) -> Array<u16> {
            ids.into_iter().map(|id| self.speed(id)).collect()
        }

        fn chance(self: @ContractState, id: felt252) -> u8 {
            self.chances.read(id)
        }

        fn chances(self: @ContractState, ids: Array<felt252>) -> Array<u8> {
            ids.into_iter().map(|id| self.chance(id)).collect()
        }

        fn cooldown(self: @ContractState, id: felt252) -> u32 {
            self.cooldowns.read(id)
        }

        fn cooldowns(self: @ContractState, ids: Array<felt252>) -> Array<u32> {
            ids.into_iter().map(|id| self.cooldown(id)).collect()
        }

        fn success(self: @ContractState, id: felt252) -> Array<Effect> {
            StorePacking::unpack(self.successes.read(id))
        }

        fn successes(self: @ContractState, ids: Array<felt252>) -> Array<Array<Effect>> {
            ids.into_iter().map(|id| self.success(id)).collect()
        }

        fn fail(self: @ContractState, id: felt252) -> Array<Effect> {
            StorePacking::unpack(self.fails.read(id))
        }

        fn fails(self: @ContractState, ids: Array<felt252>) -> Array<Array<Effect>> {
            ids.into_iter().map(|id| self.fail(id)).collect()
        }

        fn action_id(
            self: @ContractState,
            name: ByteArray,
            speed: u16,
            chance: u8,
            cooldown: u32,
            success: Array<Effect>,
            fail: Array<Effect>,
        ) -> felt252 {
            ActionWithName { name, speed, chance, cooldown, success, fail }.action_id()
        }

        fn action_ids(self: @ContractState, actions: Array<ActionWithName>) -> Array<felt252> {
            actions.into_iter().map(|action| action.action_id()).collect()
        }

        fn tag(self: @ContractState, tag: felt252) -> felt252 {
            self.tags.read(tag)
        }
    }

    #[abi(embed_v0)]
    impl IActionAdminImpl of IActionAdmin<ContractState> {
        fn create_action(
            ref self: ContractState,
            name: ByteArray,
            speed: u16,
            chance: u8,
            cooldown: u32,
            success: Array<Effect>,
            fail: Array<Effect>,
        ) -> felt252 {
            self.assert_caller_is_writer();
            self._create_action(ActionWithName { name, speed, chance, cooldown, success, fail })
        }

        fn create_actions(
            ref self: ContractState, actions: Array<ActionWithName>,
        ) -> Array<felt252> {
            self.assert_caller_is_writer();
            let mut action_ids: Array<felt252> = Default::default();
            for action in actions {
                action_ids.append(self._create_action(action))
            }
            action_ids
        }
        fn maybe_create_actions(
            ref self: ContractState, actions: Array<IdTagAction>,
        ) -> Array<felt252> {
            self.assert_caller_is_writer();
            let mut action_ids: Array<felt252> = Default::default();

            for maybe_action in actions {
                let action_id = match maybe_action {
                    IdTagAction::Id(action_id) => { action_id },
                    IdTagAction::Tag(tag) => { self.tags.read(byte_array_to_tag(@tag)) },
                    IdTagAction::Action(action) => { self._create_action(action) },
                };
                action_ids.append(action_id);
            }
            action_ids
        }
        fn maybe_create_actions_array(
            ref self: ContractState, actions: Array<Array<IdTagAction>>,
        ) -> Array<Array<felt252>> {
            self.assert_caller_is_writer();
            let mut all_action_ids: Array<Array<felt252>> = Default::default();
            for action_array in actions {
                let mut action_ids: Array<felt252> = Default::default();
                for maybe_action in action_array {
                    let action_id = match maybe_action {
                        IdTagAction::Id(action_id) => { action_id },
                        IdTagAction::Tag(tag) => { self.tags.read(byte_array_to_tag(@tag)) },
                        IdTagAction::Action(action) => { self._create_action(action) },
                    };
                    action_ids.append(action_id);
                }
                all_action_ids.append(action_ids);
            }
            all_action_ids
        }
    }


    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn _create_action(ref self: ContractState, action: ActionWithName) -> felt252 {
            let snapshot = @action;
            let success = StorePacking::pack(action.success);
            let fail = StorePacking::pack(action.fail);
            let action_id = get_action_id(
                @action.name,
                action.speed,
                action.chance,
                action.cooldown,
                success.span(),
                fail.span(),
            );
            self.tags.write(byte_array_to_tag(@action.name), action_id);
            // let action: Action = action.into();
            if self.chances.read(action_id).is_non_zero() {
                return action_id; // Action already exists
            }
            assert(0 < action.chance && action.chance <= 100, 'Chance must between 0 and 100');

            ActionTable::set_entity(action_id, snapshot);
            self.speeds.write(action_id, action.speed);
            self.chances.write(action_id, action.chance);
            self.cooldowns.write(action_id, action.cooldown);
            self.successes.write(action_id, success);
            self.fails.write(action_id, fail);

            action_id
        }
    }
}

