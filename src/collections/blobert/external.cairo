use starknet::ContractAddress;
use super::super::TokenAttributes;

/// Interface for Blobert NFT collection management
/// # Interface Functions
/// * `traits` - Returns the attributes/traits associated with a specific token ID
/// * `owner_of` - Retrieves the owner address of a specific token ID
/// * `get_approved` - Gets the approved address for a specific token ID
/// * `is_approved_for_all` - Checks if an operator is approved to manage all tokens of an owner
///
/// # Arguments
/// * `token_id` - The unique identifier of the token
/// * `owner` - The address of the token owner
/// * `operator` - The address to check for approval
///
/// # Returns
/// * `traits` - Returns TokenAttributes struct containing token traits
/// * `owner_of` - Returns ContractAddress of token owner
/// * `get_approved` - Returns ContractAddress of approved operator
/// * `is_approved_for_all` - Returns boolean indicating approval status
#[starknet::interface]
trait IBlobert<TContractState> {
    fn traits(self: @TContractState, token_id: u256) -> TokenAttributes;
    fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress;
    fn get_approved(self: @TContractState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(
        self: @TContractState, owner: ContractAddress, operator: ContractAddress,
    ) -> bool;
}
