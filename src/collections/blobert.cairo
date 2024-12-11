mod external;
mod items;
use dojo::world::{WorldStorage};
use blob_arena::{
    collections::blobert::items::BlobertTrait, attacks::components::AttackInput, stats::UStats
};


#[starknet::interface]
trait IBlobertItems<TContractState> {
    fn set_seed_item_id(
        ref self: TContractState, blobert_trait: BlobertTrait, trait_id: u8, item_id: felt252
    );
    fn set_custom_item_id(
        ref self: TContractState, blobert_trait: BlobertTrait, trait_id: u8, item_id: felt252
    );
    fn new_seed_item_with_attacks(
        ref self: TContractState,
        blobert_trait: BlobertTrait,
        trait_id: u8,
        item_name: ByteArray,
        stats: UStats,
        attacks: Array<AttackInput>
    );
    fn new_custom_item_with_attacks(
        ref self: TContractState,
        blobert_trait: BlobertTrait,
        trait_id: u8,
        item_name: ByteArray,
        stats: UStats,
        attacks: Array<AttackInput>
    );
}
#[dojo::contract]
mod blobert_actions {
    use starknet::{ContractAddress, get_contract_address};
    use dojo::world::WorldStorage;
    use blob_arena::{
        collections::{
            interface::{ICollection, IERC721Dispatcher, IERC721DispatcherTrait},
            blobert::{
                items::{
                    BlobertItemsTrait, BlobertTrait, BlobertStatsTrait, SEED_TRAIT_TYPE,
                    CUSTOM_TRAIT_TYPE
                },
                external::{
                    get_erc271_dispatcher, get_blobert_dispatcher, IBlobertDispatcher,
                    IBlobertDispatcherTrait, TokenTrait
                }
            }
        },
        items::ItemTrait, world::WorldTrait, attacks::components::AttackInput, stats::UStats, uuid,
        default_namespace
    };
    use super::IBlobertItems;

    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn get_blobert_traits(self: @WorldStorage, token_id: u256) -> TokenTrait {
            let dispatcher = get_blobert_dispatcher();
            dispatcher.traits(token_id)
        }
    }

    #[abi(embed_v0)]
    impl ICollectionImpl of ICollection<ContractState> {
        fn get_owner(self: @ContractState, token_id: u256) -> ContractAddress {
            let dispatcher = get_erc271_dispatcher();
            IERC721DispatcherTrait::owner_of(dispatcher, token_id)
        }
        fn get_stats(self: @ContractState, token_id: u256) -> UStats {
            let mut world = self.world(default_namespace());
            let traits = world.get_blobert_traits(token_id);
            world.get_blobert_stats(traits)
        }
        fn get_item_ids(self: @ContractState, token_id: u256) -> Span<felt252> {
            let mut world = self.world(default_namespace());
            let traits = world.get_blobert_traits(token_id);
            world.get_blobert_item_ids(traits).span()
        }
        fn has_attack(
            self: @ContractState, token_id: u256, item_id: felt252, attack_id: felt252
        ) -> bool {
            let mut world = self.world(default_namespace());
            let traits = world.get_blobert_traits(token_id);
            world.blobert_has_attack(traits, item_id, attack_id)
        }
    }
    #[abi(embed_v0)]
    impl IBlobertItemsImpl of IBlobertItems<ContractState> {
        fn set_seed_item_id(
            ref self: ContractState, blobert_trait: BlobertTrait, trait_id: u8, item_id: felt252
        ) {
            let mut world = self.world(default_namespace());
            world.assert_caller_is_creator();
            world.set_item_id(SEED_TRAIT_TYPE, blobert_trait, trait_id, item_id);
        }
        fn set_custom_item_id(
            ref self: ContractState, blobert_trait: BlobertTrait, trait_id: u8, item_id: felt252
        ) {
            let mut world = self.world(default_namespace());
            world.assert_caller_is_creator();
            world.set_item_id(CUSTOM_TRAIT_TYPE, blobert_trait, trait_id, item_id);
        }
        fn new_seed_item_with_attacks(
            ref self: ContractState,
            blobert_trait: BlobertTrait,
            trait_id: u8,
            item_name: ByteArray,
            stats: UStats,
            attacks: Array<AttackInput>
        ) {
            let mut world = self.world(default_namespace());
            world.assert_caller_is_creator();
            let item_id = world.create_new_item_with_attacks(item_name, stats, attacks);
            world.set_item_id(SEED_TRAIT_TYPE, blobert_trait, trait_id, item_id);
        }
        fn new_custom_item_with_attacks(
            ref self: ContractState,
            blobert_trait: BlobertTrait,
            trait_id: u8,
            item_name: ByteArray,
            stats: UStats,
            attacks: Array<AttackInput>
        ) {
            let mut world = self.world(default_namespace());
            world.assert_caller_is_creator();
            let item_id = world.create_new_item_with_attacks(item_name, stats, attacks);
            world.set_item_id(CUSTOM_TRAIT_TYPE, blobert_trait, trait_id, item_id);
        }
    }
}

