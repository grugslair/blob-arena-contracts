use ba_combat::Action;
use starknet::{ClassHash, ContractAddress};

/// Main interface for arcade gameplay functionality
///
/// Provides the core game mechanics for players to start arcade attempts,
/// execute actions, manage respawns, and forfeit attempts.
#[starknet::interface]
pub trait IArcade<TState> {
    /// Starts a new arcade attempt for the specified NFT
    ///
    /// Creates a new arcade session using the player's NFT and selected action loadout.
    /// The player must have sufficient energy/credits and the NFT must be valid.
    ///
    /// # Arguments
    /// * `collection_address` - The NFT collection contract address
    /// * `token_id` - The specific NFT token ID to use for this attempt
    /// * `action_slots` - Array of action slot configurations for the loadout
    ///
    /// # Returns
    /// * `felt252` - Unique identifier for the created arcade attempt
    fn start(
        ref self: TState,
        collection_address: ContractAddress,
        token_id: u256,
        action_slots: Array<Array<felt252>>,
    ) -> felt252;

    /// Executes an action in the current combat round
    ///
    /// Performs the specified action against the current opponent in the arcade attempt.
    /// The action must be available in the player's loadout and not on cooldown.
    ///
    /// # Arguments
    /// * `attempt_id` - The arcade attempt identifier
    /// * `action_id` - The action to execute (must be in the player's loadout)
    fn act(ref self: TState, attempt_id: felt252, action: Action);

    /// Respawns the player's character after defeat
    ///
    /// Uses one of the player's available respawns to continue the arcade attempt
    /// from the current stage with restored health.
    ///
    /// # Arguments
    /// * `attempt_id` - The arcade attempt identifier
    fn respawn(ref self: TState, attempt_id: felt252);

    /// Forfeits the current arcade attempt
    ///
    /// Voluntarily ends the arcade attempt, forfeiting any potential rewards
    /// but allowing the player to start a new attempt.
    ///
    /// # Arguments
    /// * `attempt_id` - The arcade attempt identifier to forfeit
    fn forfeit(ref self: TState, attempt_id: felt252);
}
/// Administrative interface for configuring arcade game parameters
///
/// Provides functions to query and modify arcade game settings such as costs,
/// time limits, respawn counts, and external contract addresses.
#[starknet::interface]
pub trait IArcadeSetup<TState> {
    /// Gets the energy cost required to start an arcade attempt
    ///
    /// # Returns
    /// * `u64` - Energy cost per arcade attempt
    fn energy_cost(self: @TState) -> u64;

    /// Gets the credit cost required to start an arcade attempt
    ///
    /// # Returns
    /// * `u128` - Credit cost per arcade attempt
    fn credit_cost(self: @TState) -> u128;

    /// Gets the maximum number of respawns allowed per arcade attempt
    ///
    /// # Returns
    /// * `u32` - Maximum respawns per attempt
    fn max_respawns(self: @TState) -> u32;

    /// Gets the time limit for arcade attempts in seconds
    ///
    /// # Returns
    /// * `u64` - Time limit in seconds (0 means no time limit)
    fn time_limit(self: @TState) -> u64;

    /// Gets the health regeneration percentage between stages
    ///
    /// # Returns
    /// * `u8` - Health regen as percentage (0-100)
    fn health_regen_percent(self: @TState) -> u8;

    /// Gets the address of the credit token contract
    ///
    /// # Returns
    /// * `ContractAddress` - Address of the credit/currency contract
    fn credit_address(self: @TState) -> ContractAddress;

    /// Gets the class hash of the combat contract used for battles
    ///
    /// # Returns
    /// * `ClassHash` - Class hash of the combat implementation
    fn combat_class_hash(self: @TState) -> ClassHash;

    /// Sets the maximum number of respawns allowed per arcade attempt
    ///
    /// # Arguments
    /// * `max_respawns` - New maximum respawn count
    fn set_max_respawns(ref self: TState, max_respawns: u32);

    /// Sets the time limit for arcade attempts
    ///
    /// # Arguments
    /// * `time_limit` - New time limit in seconds (0 for no limit)
    fn set_time_limit(ref self: TState, time_limit: u64);

    /// Sets the health regeneration percentage between stages
    ///
    /// # Arguments
    /// * `health_regen_percent` - Health regen percentage (0-100)
    fn set_health_regen_percent(ref self: TState, health_regen_percent: u8);

    /// Sets the address of the credit token contract
    ///
    /// # Arguments
    /// * `contract_address` - Address of the new credit contract
    fn set_credit_address(ref self: TState, contract_address: ContractAddress);

    /// Sets both energy and credit costs for arcade attempts
    ///
    /// # Arguments
    /// * `energy` - New energy cost per attempt
    /// * `credit` - New credit cost per attempt
    fn set_cost(ref self: TState, energy: u64, credit: u128);

    /// Sets the class hash of the combat contract implementation
    ///
    /// # Arguments
    /// * `class_hash` - New combat contract class hash
    fn set_combat_class_hash(ref self: TState, class_hash: ClassHash);
}
