mod blobert;
mod mint;
mod amma;
use starknet::ContractAddress;
use dojo::world::{WorldStorage};
use blob_arena::collections::blobert::external::TokenTrait;

#[starknet::interface]
trait IArcadeBlobert<TContractState> {
    fn mint(ref self: TContractState) -> u256;
    fn traits(self: @TContractState, token_id: u256) -> TokenTrait;
}

#[starknet::interface]
trait IAMMABlobert<TContractState> {
    fn mint_amma(ref self: TContractState, fighter: u8) -> felt252;
    fn set_amma_fighter(ref self: TContractState, fighter_id: u8, name: ByteArray, custom_id: u8);
}

#[dojo::contract]
mod arcade_blobert_actions {
    use starknet::{ContractAddress, get_caller_address};
    use blob_arena::{
        collections::{
            interface::ICollection,
            blobert::{items::{BlobertItemsTrait, BlobertStatsTrait}, external::TokenTrait},
            arcade_blobert::{
                blobert::{ArcadeBlobert, ArcadeBlobertTrait}, mint::ArcadeBlobertMintTrait,
                amma::AMMABlobertTrait
            },
        },
        stats::UStats, default_namespace
    };
    use super::{IArcadeBlobert, IAMMABlobert};
    #[abi(embed_v0)]
    impl ICollectionImpl of ICollection<ContractState> {
        fn get_owner(self: @ContractState, token_id: u256) -> ContractAddress {
            let mut world = self.world(default_namespace());
            world.get_arcade_blobert_owner(token_id)
        }
        fn get_item_ids(self: @ContractState, token_id: u256) -> Span<felt252> {
            let mut world = self.world(default_namespace());
            let traits = world.get_arcade_blobert_traits(token_id);
            world.get_blobert_item_ids(traits).span()
        }

        fn get_stats(self: @ContractState, token_id: u256) -> UStats {
            let mut world = self.world(default_namespace());
            let traits = world.get_arcade_blobert_traits(token_id);
            world.get_blobert_stats(traits)
        }
        fn has_attack(
            self: @ContractState, token_id: u256, item_id: felt252, attack_id: felt252
        ) -> bool {
            let mut world = self.world(default_namespace());
            let traits = world.get_arcade_blobert_traits(token_id);
            world.blobert_has_attack(traits, item_id, attack_id)
        }
    }

    #[abi(embed_v0)]
    impl IArcadeBlobertImpl of IArcadeBlobert<ContractState> {
        fn mint(ref self: ContractState) -> u256 {
            let mut world = self.world(default_namespace());
            world.mint_blobert()
        }
        fn traits(self: @ContractState, token_id: u256) -> TokenTrait {
            let mut world = self.world(default_namespace());
            world.get_arcade_blobert_traits(token_id)
        }
    }

    #[abi(embed_v0)]
    impl IAMMABlobertImpl of IAMMABlobert<ContractState> {
        fn mint_amma(ref self: ContractState, fighter: u8) -> felt252 {
            let mut world = self.world(default_namespace());
            let caller = get_caller_address();
            world.mint_amma_blobert(caller, fighter)
        }
        fn set_amma_fighter(
            ref self: ContractState, fighter_id: u8, name: ByteArray, custom_id: u8
        ) {
            let mut world = self.world(default_namespace());
            world.set_amma_blobert(fighter_id, name, custom_id);
        }
    }
}

