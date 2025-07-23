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
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
    };
    use crate::ability::Abilities;
    use crate::attack::{AttackWithName, IAttackAdminDispatcher, IAttackAdminDispatcherTrait};
    use crate::interface::ILoadout;
    use super::IAmmaBlobertLoadout;

    #[storage]
    struct Storage {
        collection_address: ContractAddress,
        attack_dispatcher: IAttackAdminDispatcher,
        attack_slots: Map<(u32, u32), felt252>,
        abilities: Map<u32, Abilities>,
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
