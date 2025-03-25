use starknet::ContractAddress;
use blob_arena::stats::UStats;

/// Interface for managing NFT collections with game-specific functionality
#[starknet::interface]
trait ICollection<TContractState> {
    /// Returns the owner address of a specific token
    /// # Arguments
    /// * `token_id` - The unique identifier of the token
    /// # Returns
    /// * `ContractAddress` - The address of the token owner
    fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress;

    /// Retrieves the stats for a specific token
    /// # Arguments
    /// * `token_id` - The unique identifier of the token
    /// # Returns
    /// * `UStats` - The stats associated with the token
    fn get_stats(self: @TContractState, token_id: u256) -> UStats;

    /// Gets the attack value for a specific item slot of a token
    /// # Arguments
    /// * `token_id` - The unique identifier of the token
    /// * `item_id` - The identifier of the item
    /// * `slot` - The slot identifier
    /// # Returns
    /// * `felt252` - The attack value for the specified slot
    fn get_attack_slot(
        self: @TContractState, token_id: u256, item_id: felt252, slot: felt252,
    ) -> felt252;

    /// Gets attack values for multiple item slots of a token
    /// # Arguments
    /// * `token_id` - The unique identifier of the token
    /// * `item_slots` - Array of tuples containing item IDs and their corresponding slots
    /// # Returns
    /// * `Array<felt252>` - Array of attack values for the specified slots
    fn get_attack_slots(
        self: @TContractState, token_id: u256, item_slots: Array<(felt252, felt252)>,
    ) -> Array<felt252>;
}

fn get_collection_dispatcher(contract_address: ContractAddress) -> ICollectionDispatcher {
    ICollectionDispatcher { contract_address }
}

