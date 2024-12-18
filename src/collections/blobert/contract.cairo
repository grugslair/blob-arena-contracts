use blob_arena::{attacks::components::AttackInput, stats::UStats};
use super::{TokenAttributes, BlobertAttribute, Seed, BlobertItemKey};


#[dojo::contract]
mod blobert_actions {
    use starknet::{ContractAddress, get_contract_address};
    use dojo::world::WorldStorage;
    use blob_arena::{
        collections::interface::ICollection, attacks::components::AttackInput, stats::UStats,
        world::default_namespace, DefaultStorage
    };
    use super::super as blobert;
    use blobert::{
        TokenAttributes, BlobertAttribute, Seed, BlobertItemKey, BlobertTrait, BlobertStorage,
        to_seed_key, external::{get_blobert_dispatcher, IBlobertDispatcherTrait}
    };

    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn get_blobert_attributes(self: @WorldStorage, token_id: u256) -> TokenAttributes {
            get_blobert_dispatcher().traits(token_id)
        }
    }

    impl DefaultStorageImpl of DefaultStorage<ContractState> {
        fn default_storage(self: @ContractState) -> WorldStorage {
            self.world(@"blobert")
        }
    }

    #[abi(embed_v0)]
    impl IBlobertLocalItems = blobert::items::IBlobertItemsImpl<ContractState>;

    #[abi(embed_v0)]
    impl ICollectionImpl of ICollection<ContractState> {
        fn owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
            get_blobert_dispatcher().owner_of(token_id)
        }
        fn get_approved(self: @ContractState, token_id: u256) -> ContractAddress {
            get_blobert_dispatcher().get_approved(token_id)
        }
        fn is_approved_for_all(
            self: @ContractState, owner: ContractAddress, operator: ContractAddress
        ) -> bool {
            get_blobert_dispatcher().is_approved_for_all(owner, operator)
        }
        fn get_stats(self: @ContractState, token_id: u256) -> UStats {
            let storage = self.default_storage();
            storage.get_blobert_stats(storage.get_blobert_attributes(token_id))
        }
        fn get_attack_slot(
            self: @ContractState, token_id: u256, item_id: felt252, slot: felt252
        ) -> felt252 {
            let storage = self.default_storage();
            storage.get_blobert_attack(storage.get_blobert_attributes(token_id), item_id, slot)
        }
        fn get_attack_slots(
            self: @ContractState, token_id: u256, item_slots: Array<(felt252, felt252)>
        ) -> Array<felt252> {
            let storage = self.default_storage();
            storage.get_blobert_attacks(storage.get_blobert_attributes(token_id), item_slots)
        }
    }
}

