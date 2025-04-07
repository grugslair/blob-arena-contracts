use starknet::ContractAddress;
use dojo::world::WorldStorage;
use blob_arena::{
    stats::UStats,
    collections::{blobert::{TokenAttributes, BlobertStorage, BlobertTrait}, ICollection}
};

trait BlobertCollectionTrait<TContractState> {
    fn blobert_storage(self: @TContractState) -> WorldStorage;
    fn attributes(self: @TContractState, token_id: u256) -> TokenAttributes;
    fn owner(self: @TContractState, token_id: u256) -> ContractAddress;
}


#[starknet::embeddable]
impl IBlobertCollectionImpl<
    TContractState, +BlobertCollectionTrait<TContractState>
> of ICollection<TContractState> {
    fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress {
        self.owner(token_id)
    }
    fn get_approved(self: @TContractState, token_id: u256) -> ContractAddress {
        Zeroable::zero()
    }
    fn is_approved_for_all(
        self: @TContractState, owner: ContractAddress, operator: ContractAddress
    ) -> bool {
        false
    }
    fn get_stats(self: @TContractState, token_id: u256) -> UStats {
        self.blobert_storage().get_blobert_stats(self.attributes(token_id))
    }
    fn get_attack_slot(
        self: @TContractState, token_id: u256, item_id: felt252, slot: felt252
    ) -> felt252 {
        self.blobert_storage().get_blobert_attack(self.attributes(token_id), item_id, slot)
    }
    fn get_attack_slots(
        self: @TContractState, token_id: u256, item_slots: Array<(felt252, felt252)>
    ) -> Array<felt252> {
        self.blobert_storage().get_blobert_attacks(self.attributes(token_id), item_slots)
    }
}
