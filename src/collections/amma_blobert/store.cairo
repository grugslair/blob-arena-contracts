use starknet::ContractAddress;

use dojo::world::{WorldStorage, IWorldDispatcher};

use crate::stats::UStats;

use super::{TokenAttributes, items::BlobertItemsTrait};

trait BlobertStore {
    fn item_store(self: @IWorldDispatcher) -> WorldStorage;
    fn local_store(self: @IWorldDispatcher) -> WorldStorage;
    fn attributes(self: @IWorldDispatcher, token_id: u256) -> TokenAttributes;
    fn owner(self: @IWorldDispatcher, token_id: u256) -> ContractAddress;
}

#[generate_trait]
impl BlobertItemsStore<impl BlobertStore: super::BlobertStore> of BlobertItems<> {
    fn get_base_stats(self: @IWorldDispatcher, token_id: u256) -> UStats {
        match self.attributes(token_id) {
            TokenAttributes::Custom(fighter) => { 
                self.get_amma_fighter_stats(fighter)
            }
            TokenAttributes::Seed => {
                panic!("Amma is not a sed ")
            }
        }
    }
    fn get_attack_slot(
        self: @IWorldDispatcher, token_id: u256, item_id: felt252, slot: felt252,
    ) -> felt252 {
        
    }
    fn get_attack_slots(
        self: @IWorldDispatcher, token_id: u256, item_slots: Array<(felt252, felt252)>,
    ) -> Array<felt252> {
        self.item_store().get_blobert_attacks(self.attributes(token_id), item_slots)
    }
}
