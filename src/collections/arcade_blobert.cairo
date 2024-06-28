mod blobert;
mod mint;
use starknet::ContractAddress;
use dojo::world::{IWorldDispatcher};
use blob_arena::collections::blobert::external::TokenTrait;

#[dojo::interface]
trait IArcadeBlobert<TContractState> {
    fn mint(ref world: IWorldDispatcher) -> u256;
    fn mint_with_traits(ref world: IWorldDispatcher, player: ContractAddress, traits: TokenTrait) -> u256;
    fn traits(world: @IWorldDispatcher, token_id: u256) -> TokenTrait;
}

#[dojo::contract]
mod arcade_blobert_actions {
    use starknet::ContractAddress;
    use blob_arena::collections::{
        interface::ICollection, blobert::{items::BlobertItemsTrait, external::TokenTrait},
        arcade_blobert::{blobert::{ArcadeBlobert, ArcadeBlobertTrait}, mint::ArcadeBlobertMintTrait}
    };
    use super::IArcadeBlobert;


    #[abi(embed_v0)]
    impl ICollectionImpl of ICollection<ContractState> {
        fn owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
            let world = self.world();
            world.get_owner(token_id)
        }

        fn get_items(self: @ContractState, token_id: u256) -> Span<u128> {
            let world = self.world();
            let blobert_trait = world.get_traits(token_id);
            let (background, armour, jewelry, mask, weapon) = world.get_item_ids(blobert_trait);
            array![background, armour, jewelry, mask, weapon].span()
        }
    }

    #[abi(embed_v0)]
    impl IArcadeBlobertImpl of IArcadeBlobert<ContractState> {
        fn mint(ref world: IWorldDispatcher) -> u256 {
            world.mint_blobert()
        }
        fn mint_with_traits(ref world: IWorldDispatcher, player: ContractAddress, traits: TokenTrait) -> u256{
            world.mint_blobert_with_traits(player, traits)
            
        }
        fn traits(world: @IWorldDispatcher, token_id: u256) -> TokenTrait {
            world.get_traits(token_id)
        }
        
    }
}
