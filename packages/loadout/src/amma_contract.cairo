use crate::ability::Abilities;
use crate::attack::AttackWithName;

#[starknet::interface]
pub trait IAmmaBlobertLoadout<TContractState> {
    fn set_fighter(
        ref self: TContractState,
        fighter: u32,
        abilities: Abilities,
        attacks: Array<AttackWithName>,
    );
}

#[starknet::contract]
mod amma_blobert_loadout {
    use amma_blobert::get_fighter;
    use sai_access::{AccessTrait, access_component};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ClassHash, ContractAddress};
    use torii_beacon::emitter::const_entity;
    use torii_beacon::emitter_component;
    use crate::ability::Abilities;
    use crate::attack::{AttackWithName, IAttackAdminDispatcher, IAttackAdminDispatcherTrait};
    use crate::interface::ILoadout;
    use super::IAmmaBlobertLoadout;

    component!(path: emitter_component, storage: emitter, event: EmitterEvents);
    component!(path: access_component, storage: access, event: AccessEvents);

    const TABLE_ID: felt252 = bytearrays_hash!("amma_blobert_loadout", "AmmaBlobertLoadout");
    impl TokenEmitter = const_entity::ConstEntityEmitter<TABLE_ID, ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        emitter: emitter_component::Storage,
        #[substorage(v0)]
        access: access_component::Storage,
        collection_address: ContractAddress,
        attack_dispatcher: IAttackAdminDispatcher,
        attack_slots: Map<(u32, u32), felt252>,
        abilities: Map<u32, Abilities>,
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
        collection_address: ContractAddress,
        attack_dispatcher_address: ContractAddress,
        blobert_loadout_class_hash: ClassHash,
    ) {
        self.grant_owner(owner);
        self.collection_address.write(collection_address);
        self
            .attack_dispatcher
            .write(IAttackAdminDispatcher { contract_address: attack_dispatcher_address });
        self
            .emit_register_model(
                "amma_blobert_loadout", "AmmaBlobertLoadout", blobert_loadout_class_hash,
            );
    }

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
                attack_ids
                    .append(self.attack_slots.read((fighter, (*slot[0]).try_into().unwrap())));
            }
            attack_ids
        }
    }

    #[abi(embed_v0)]
    impl IAmmaBlobertLoadoutImpl of IAmmaBlobertLoadout<ContractState> {
        fn set_fighter(
            ref self: ContractState,
            fighter: u32,
            abilities: Abilities,
            attacks: Array<AttackWithName>,
        ) {
            assert(fighter > 0, 'Fighter must be greater than 0');
            let mut attack_dispatcher = self.attack_dispatcher.read();
            let attack_ids = attack_dispatcher.create_attacks(attacks);
            self.abilities.write(fighter, abilities);
            for (i, attack_id) in attack_ids.into_iter().enumerate() {
                self.attack_slots.write((fighter, i), attack_id);
            }
        }
    }
}
