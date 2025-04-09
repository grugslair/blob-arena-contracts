use starknet::ContractAddress;

use crate::stats::UStats;
use crate::world::{WorldDispatcher, WorldComponent};
use super::{ICollection, BlobertItems};

#[starknet::embeddable]
impl IBlobertCollectionImpl<
    TContractState, impl BlobertStore: super::BlobertStore, +WorldComponent<TContractState>,
> of ICollection<TContractState> {
    fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress {
        self.world_dispatcher().owner(token_id)
    }
    fn get_stats(self: @TContractState, token_id: u256) -> UStats {
        self.world_dispatcher().get_base_stats(token_id)
    }
    fn get_attack_slot(
        self: @TContractState, token_id: u256, item_id: felt252, slot: felt252,
    ) -> felt252 {
        self.world_dispatcher().get_attack_slot(token_id, item_id, slot)
    }
    fn get_attack_slots(
        self: @TContractState, token_id: u256, item_slots: Array<(felt252, felt252)>,
    ) -> Array<felt252> {
        self.world_dispatcher().get_attack_slots(token_id, item_slots)
    }
}
