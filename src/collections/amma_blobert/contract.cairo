use starknet::ContractAddress;
use blob_arena::collections::blobert::TokenAttributes;

#[starknet::interface]
trait IAMMABlobert<TContractState> {
    fn mint(ref self: TContractState, fighter: felt252) -> felt252;
    fn traits(self: @TContractState, token_id: u256) -> TokenAttributes;
}

#[dojo::contract]
mod amma_blobert_actions {
    use starknet::{ContractAddress, get_caller_address};
    use dojo::world::WorldStorage;
    use blob_arena::{
        DefaultStorage, attacks::components::AttackInput, stats::UStats, default_namespace,
        hash::hash_value
    };
    use blob_arena::collections::{blobert, arcade_blobert, interface::ICollection};
    use arcade_blobert::{ArcadeBlobertStorage, BlobertCollectionTrait};
    use blobert::{
        blobert_namespace, BlobertTrait, BlobertStorage, TokenAttributes, BlobertItemKey,
        to_seed_key, BlobertAttribute
    };
    use super::IAMMABlobert;

    impl DefaultStorageImpl of DefaultStorage<ContractState> {
        fn default_storage(self: @ContractState) -> WorldStorage {
            self.world(@"amma_blobert")
        }
    }

    impl ArcadeBlobertCollectionImpl of BlobertCollectionTrait<ContractState> {
        fn blobert_storage(self: @ContractState) -> WorldStorage {
            self.default_storage()
        }
        fn attributes(self: @ContractState, token_id: u256) -> TokenAttributes {
            self.default_storage().get_blobert_token_attributes(token_id)
        }
        fn owner(self: @ContractState, token_id: u256) -> ContractAddress {
            self.default_storage().get_blobert_token_owner(token_id)
        }
    }

    #[abi(embed_v0)]
    impl IAMMABlobertItems = blobert::items::IBlobertItemsImpl<ContractState>;

    #[abi(embed_v0)]
    impl IArcadeBlobertCollectionImpl =
        arcade_blobert::collection::IBlobertCollectionImpl<ContractState>;

    #[abi(embed_v0)]
    impl IAMMABlobertImpl of IAMMABlobert<ContractState> {
        fn mint(ref self: ContractState, fighter: felt252) -> felt252 {
            let mut storage = self.default_storage();
            let owner = get_caller_address();
            let id = hash_value((owner, fighter));
            storage.set_blobert_token(id, owner, TokenAttributes::Custom(fighter));
            id
        }
        fn traits(self: @ContractState, token_id: u256) -> TokenAttributes {
            let storage = self.default_storage();
            storage.get_blobert_token_attributes(token_id)
        }
    }
}

