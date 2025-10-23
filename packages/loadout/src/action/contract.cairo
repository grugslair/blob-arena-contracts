#[starknet::contract]
mod action {
    use ba_utils::storage::{FeltArrayReadWrite, ShortArrayStore, read_at_felt252};
    use beacon_library::{ToriiTable, register_table};
    use core::num::traits::Zero;
    use sai_access::{AccessTrait, access_component};
    use sai_core_utils::poseidon_hash_two;
    use sai_core_utils::poseidon_serde::PoseidonSerde;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::storage_access::StorePacking;
    use starknet::{ClassHash, ContractAddress};
    use crate::action::action::{
        ChanceEffects, EffectArrayStorageMapReadAccess, EffectArrayStorageMapWriteAccess,
        EffectReaderTrait, Effects, byte_array_to_tag, get_effects_storage_address,
        read_all_effects, read_chance_effects, write_chance_effects,
    };
    use crate::action::effect::{EffectArrayReadWrite, EffectArrayStorePacking};
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
        cooldowns: Map<felt252, u32>,
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
            let (base_effects, chance_effects) = read_all_effects(id);
            Action {
                speed: self.speeds.read(id),
                cooldown: self.cooldowns.read(id),
                base_effects,
                chance_effects,
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


        fn cooldown(self: @ContractState, id: felt252) -> u32 {
            self.cooldowns.read(id)
        }


        fn action_id(
            self: @ContractState,
            name: ByteArray,
            speed: u16,
            cooldown: u32,
            base_effects: Array<Effect>,
            chance_effects: Array<ChanceEffects>,
        ) -> felt252 {
            ActionWithName { name, speed, cooldown, base_effects, chance_effects }.action_id()
        }
        fn get_effects(
            self: @ContractState, id: felt252, chance_value: u32,
        ) -> (u16, Array<Effect>) {
            let mut reader = EffectReaderTrait::new(id);
            reader.get_effects(chance_value)
        }
        fn base_effects(self: @ContractState, id: felt252) -> Array<Effect> {
            let effects_hash = get_effects_storage_address(id);
            EffectArrayReadWrite::read_short_array(
                poseidon_hash_two(effects_hash, 0).try_into().unwrap(),
            )
                .unwrap()
        }

        fn chance_effects(self: @ContractState, id: felt252) -> Array<ChanceEffects> {
            read_chance_effects(get_effects_storage_address(id))
        }

        fn effects(self: @ContractState, id: felt252) -> Effects {
            let (base, chance) = read_all_effects(id);
            Effects { base, chance }
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
            cooldown: u32,
            base_effects: Array<Effect>,
            chance_effects: Array<ChanceEffects>,
        ) -> felt252 {
            self.assert_caller_is_writer();
            self
                ._create_action(
                    ActionWithName { name, speed, cooldown, base_effects, chance_effects },
                )
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
            let (action, name) = action.into();
            let base_effects = StorePacking::pack(action.base_effects);
            let mut chance_effects: Array<(u32, Array<felt252>)> = Default::default();
            for ChanceEffects { chance_ppm, effects } in action.chance_effects {
                chance_effects.append((chance_ppm, StorePacking::pack(effects)));
            }
            let action_id = get_action_id(
                @name, action.speed, action.cooldown, base_effects.span(), chance_effects.span(),
            );
            let effects_hash = get_effects_storage_address(action_id);
            let effects_0_hash = poseidon_hash_two(effects_hash, 0);
            // let action: Action = action.into();
            if read_at_felt252(effects_0_hash).is_non_zero() {
                return action_id; // Action already exists
            }

            self.tags.write(byte_array_to_tag(@name), action_id);

            ActionTable::set_entity(action_id, snapshot);
            self.speeds.write(action_id, action.speed);
            self.cooldowns.write(action_id, action.cooldown);
            FeltArrayReadWrite::write_short_array(effects_0_hash.try_into().unwrap(), base_effects)
                .unwrap();
            write_chance_effects(effects_hash, chance_effects);
            action_id
        }
    }
}

