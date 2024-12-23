mod external;
mod items;
use dojo::world::{IWorldDispatcher};
use blob_arena::{
    components::{stats::Stats, item::AttackInput}, collections::blobert::items::BlobertTrait
};


#[dojo::interface]
trait IBlobertItems {
    fn set_seed_item_id(
        ref world: IWorldDispatcher, blobert_trait: BlobertTrait, trait_id: u8, item_id: felt252
    );
    fn set_custom_item_id(
        ref world: IWorldDispatcher, blobert_trait: BlobertTrait, trait_id: u8, item_id: felt252
    );
    fn new_seed_item_with_attacks(
        ref world: IWorldDispatcher,
        blobert_trait: BlobertTrait,
        trait_id: u8,
        item_name: ByteArray,
        stats: Stats,
        attacks: Array<AttackInput>
    );
    fn new_custom_item_with_attacks(
        ref world: IWorldDispatcher,
        blobert_trait: BlobertTrait,
        trait_id: u8,
        item_name: ByteArray,
        stats: Stats,
        attacks: Array<AttackInput>
    );
}

#[dojo::contract]
mod blobert_actions {
    use starknet::{ContractAddress, get_contract_address};
    use blob_arena::{
        collections::{
            interface::{ICollection, IERC721Dispatcher, IERC721DispatcherTrait},
            blobert::{
                external::{
                    get_erc271_dispatcher, get_blobert_dispatcher, IBlobertDispatcher,
                    IBlobertDispatcherTrait, TokenTrait
                },
                items::{
                    BlobertItemsTrait, BlobertTrait, BlobertStatsTrait, SEED_TRAIT_TYPE,
                    CUSTOM_TRAIT_TYPE
                }
            },
        },
        components::{stats::Stats, item::{ItemTrait, AttackInput}}, world::{WorldTrait, Contract}
    };
    use super::IBlobertItems;

    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn get_blobert_traits(self: @IWorldDispatcher, token_id: u256) -> TokenTrait {
            let dispatcher = get_blobert_dispatcher();
            dispatcher.traits(token_id)
        }
    }

    #[abi(embed_v0)]
    impl ICollectionImpl of ICollection<ContractState> {
        fn get_owner(world: @IWorldDispatcher, token_id: u256) -> ContractAddress {
            let dispatcher = get_erc271_dispatcher();
            IERC721DispatcherTrait::owner_of(dispatcher, token_id)
        }
        fn get_health(world: @IWorldDispatcher, token_id: u256) -> u8 {
            let traits = world.get_blobert_traits(token_id);
            world.get_blobert_health(traits)
        }
        fn get_stats(world: @IWorldDispatcher, token_id: u256) -> Stats {
            let traits = world.get_blobert_traits(token_id);
            world.get_blobert_stats(traits)
        }
        fn get_item_ids(world: @IWorldDispatcher, token_id: u256) -> Span<felt252> {
            let traits = world.get_blobert_traits(token_id);
            world.get_blobert_item_ids(traits).span()
        }
        fn has_attack(
            world: @IWorldDispatcher, token_id: u256, item_id: felt252, attack_id: felt252
        ) -> bool {
            let traits = world.get_blobert_traits(token_id);
            world.blobert_has_attack(traits, item_id, attack_id)
        }
    }
    #[abi(embed_v0)]
    impl IBlobertItemsImpl of IBlobertItems<ContractState> {
        fn set_seed_item_id(
            ref world: IWorldDispatcher, blobert_trait: BlobertTrait, trait_id: u8, item_id: felt252
        ) {
            world.assert_caller_is_owner();
            world.set_item_id(SEED_TRAIT_TYPE, blobert_trait, trait_id, item_id);
        }
        fn set_custom_item_id(
            ref world: IWorldDispatcher, blobert_trait: BlobertTrait, trait_id: u8, item_id: felt252
        ) {
            world.assert_caller_is_owner();
            world.set_item_id(CUSTOM_TRAIT_TYPE, blobert_trait, trait_id, item_id);
        }
        fn new_seed_item_with_attacks(
            ref world: IWorldDispatcher,
            blobert_trait: BlobertTrait,
            trait_id: u8,
            item_name: ByteArray,
            stats: Stats,
            attacks: Array<AttackInput>
        ) {
            world.assert_caller_is_owner();
            let item_id = world.create_new_item(item_name, stats);
            world.create_and_set_new_attacks(item_id, attacks);
            world.set_item_id(SEED_TRAIT_TYPE, blobert_trait, trait_id, item_id);
        }
        fn new_custom_item_with_attacks(
            ref world: IWorldDispatcher,
            blobert_trait: BlobertTrait,
            trait_id: u8,
            item_name: ByteArray,
            stats: Stats,
            attacks: Array<AttackInput>
        ) {
            world.assert_caller_is_owner();
            let item_id = world.create_new_item(item_name, stats);
            world.create_and_set_new_attacks(item_id, attacks);
            world.set_item_id(CUSTOM_TRAIT_TYPE, blobert_trait, trait_id, item_id);
        }
    }
}
