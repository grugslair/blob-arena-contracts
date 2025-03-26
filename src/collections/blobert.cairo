use blob_arena::{attacks::components::AttackInput, stats::UStats};
use super::{TokenAttributes, BlobertAttribute, Seed, BlobertItemKey};

const BLOBERT_CONTRACT_ADDRESS: felt252 =
    0x032cb9f30629268612ffb6060e40dfc669849c7d72539dd23c80fe6578d0549d;

#[dojo::contract]
mod blobert_actions {
    use starknet::{ContractAddress, get_contract_address};
    use dojo::world::{WorldStorage, IWorldDispatcher};
    use crate::world::WorldTrait;
    use super::super::BlobertStore;

    impl BlobertStoreImpl of BlobertStore {
        fn local_store(self: @IWorldDispatcher) -> WorldStorage {
            self.storage(LOCAL_NAMESPACE_HASH)
        }

        fn item_store(self: @IWorldDispatcher) -> WorldStorage {
            Self::local_store(self)
        }

        fn attributes(self: @IWorldDispatcher, token_id: u256) -> TokenAttributes {
            Self::local_store(self).get_blobert_token_attributes(token_id)
        }

        fn owner(self: @IWorldDispatcher, token_id: u256) -> ContractAddress {
            Self::local_store(self).get_blobert_token_owner(token_id)
        }
    }

    #[abi(embed_v0)]
    impl IBlobertLocalItems =
        blobert::items::IBlobertItemsImpl<ContractState, permissioned_storage::DefaultStorageImpl>;

    #[abi(embed_v0)]
    impl ICollectionImpl of ICollection<ContractState> {
        fn owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
            get_blobert_dispatcher().owner_of(token_id)
        }
        fn get_approved(self: @ContractState, token_id: u256) -> ContractAddress {
            get_blobert_dispatcher().get_approved(token_id)
        }
        fn is_approved_for_all(
            self: @ContractState, owner: ContractAddress, operator: ContractAddress,
        ) -> bool {
            get_blobert_dispatcher().is_approved_for_all(owner, operator)
        }
        fn get_stats(self: @ContractState, token_id: u256) -> UStats {
            let storage = self.default_storage();
            storage.get_blobert_stats(storage.get_blobert_attributes(token_id))
        }
        fn get_attack_slot(
            self: @ContractState, token_id: u256, item_id: felt252, slot: felt252,
        ) -> felt252 {
            let storage = self.default_storage();
            storage.get_blobert_attack(storage.get_blobert_attributes(token_id), item_id, slot)
        }
        fn get_attack_slots(
            self: @ContractState, token_id: u256, item_slots: Array<(felt252, felt252)>,
        ) -> Array<felt252> {
            let storage = self.default_storage();
            storage.get_blobert_attacks(storage.get_blobert_attributes(token_id), item_slots)
        }
    }
}

