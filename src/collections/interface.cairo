use starknet::ContractAddress;
use dojo::world::{WorldStorage};
use blob_arena::components::{stats::Stats};


#[dojo::interface]
trait IERC721 {
    fn balance_of(self: @ContractState, account: ContractAddress) -> u256;
    fn owner_of(self: @ContractState, token_id: u256) -> ContractAddress;
    fn safe_transfer_from(
        ref self: ContractState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>
    );
    fn transfer_from(
        ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256
    );
    fn approve(ref self: ContractState, to: ContractAddress, token_id: u256);
    fn set_approval_for_all(ref self: ContractState, operator: ContractAddress, approved: bool);
    fn get_approved(self: @ContractState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(
        self: @ContractState, owner: ContractAddress, operator: ContractAddress
    ) -> bool;
    fn name(self: @ContractState) -> felt252;
    fn symbol(self: @ContractState) -> felt252;
    fn token_uri(self: @ContractState, token_id: u256) -> felt252;
    fn balanceOf(self: @ContractState, account: ContractAddress) -> u256;
    fn ownerOf(self: @ContractState, tokenId: u256) -> ContractAddress;
    fn safeTransferFrom(
        ref self: ContractState,
        from: ContractAddress,
        to: ContractAddress,
        tokenId: u256,
        data: Span<felt252>
    );
    fn transferFrom(
        ref self: ContractState, from: ContractAddress, to: ContractAddress, tokenId: u256
    );
    fn setApprovalForAll(ref self: ContractState, operator: ContractAddress, approved: bool);
    fn getApproved(self: @ContractState, tokenId: u256) -> ContractAddress;
    fn isApprovedForAll(
        self: @ContractState, owner: ContractAddress, operator: ContractAddress
    ) -> bool;
    fn tokenURI(self: @ContractState, tokenId: u256) -> felt252;
}

#[dojo::interface]
trait ICollection {
    fn get_owner(self: @ContractState, token_id: u256) -> ContractAddress;
    fn get_item_ids(self: @ContractState, token_id: u256) -> Span<felt252>;
    fn get_health(self: @ContractState, token_id: u256) -> u8;
    fn get_stats(self: @ContractState, token_id: u256) -> Stats;
    fn has_attack(
        self: @ContractState, token_id: u256, item_id: felt252, attack_id: felt252
    ) -> bool;
}
fn get_collection_dispatcher(contract_address: ContractAddress) -> ICollectionDispatcher {
    ICollectionDispatcher { contract_address }
}

