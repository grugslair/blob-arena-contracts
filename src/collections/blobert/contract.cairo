use blob_arena::{attacks::components::AttackInput, stats::UStats};
use super::{TokenAttributes, BlobertAttribute, Seed, BlobertItemKey};


#[dojo::contract]
mod blobert_actions {
    use starknet::{ContractAddress, get_contract_address};
    use dojo::world::WorldStorage;
    use blob_arena::{
        collections::interface::ICollection, attacks::components::AttackInput, stats::UStats,
        world::default_namespace, DefaultStorage,
    };
    use super::super as blobert;
    use blobert::{
        TokenAttributes, BlobertAttribute, Seed, BlobertItemKey, BlobertTrait, BlobertStorage,
        to_seed_key, external::{IBlobertDispatcher, IBlobertDispatcherTrait},
    };

    fn dojo_init(ref self: ContractState, blobert_contract_address: ContractAddress) {
        self.blobert_contract_address.write(blobert_contract_address);
    }

    #[storage]
    struct Storage {
        blobert_contract_address: ContractAddress,
    }

    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn blobert_dispatcher(self: @ContractState) -> IBlobertDispatcher {
            IBlobertDispatcher { contract_address: self.blobert_contract_address.read() }
        }

        fn get_blobert_attributes(self: @ContractState, token_id: u256) -> TokenAttributes {
            self.blobert_dispatcher().traits(token_id)
        }
    }

    impl DefaultStorageImpl of DefaultStorage<ContractState> {
        fn default_storage(self: @ContractState) -> WorldStorage {
            self.world(@"blobert")
        }
    }

    mod permissioned_storage {
        use super::{DefaultStorage, ContractState, WorldStorage};
        use blob_arena::{permissions::{Permissions, Role}, world::get_default_storage};
        impl DefaultStorageImpl of DefaultStorage<ContractState> {
            fn default_storage(self: @ContractState) -> WorldStorage {
                get_default_storage().assert_caller_has_permission(Role::BlobertAdmin);
                super::DefaultStorageImpl::default_storage(self)
            }
        }
    }

    #[abi(embed_v0)]
    impl IBlobertLocalItems =
        blobert::items::IBlobertItemsImpl<ContractState, permissioned_storage::DefaultStorageImpl>;

    #[abi(embed_v0)]
    impl ICollectionImpl of ICollection<ContractState> {
        fn owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
            self.blobert_dispatcher().owner_of(token_id)
        }
        fn get_approved(self: @ContractState, token_id: u256) -> ContractAddress {
            self.blobert_dispatcher().get_approved(token_id)
        }
        fn is_approved_for_all(
            self: @ContractState, owner: ContractAddress, operator: ContractAddress,
        ) -> bool {
            self.blobert_dispatcher().is_approved_for_all(owner, operator)
        }
        fn get_stats(self: @ContractState, token_id: u256) -> UStats {
            let storage = self.default_storage();
            storage.get_blobert_stats(self.get_blobert_attributes(token_id))
        }
        fn get_attack_slot(
            self: @ContractState, token_id: u256, item_id: felt252, slot: felt252,
        ) -> felt252 {
            let storage = self.default_storage();
            storage.get_blobert_attack(self.get_blobert_attributes(token_id), item_id, slot)
        }
        fn get_attack_slots(
            self: @ContractState, token_id: u256, item_slots: Array<(felt252, felt252)>,
        ) -> Array<felt252> {
            let storage = self.default_storage();
            storage.get_blobert_attacks(self.get_blobert_attributes(token_id), item_slots)
        }
    }
}

