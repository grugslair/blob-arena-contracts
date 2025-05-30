use super::interface::ERC721ABI;
use super::internal::{
    ERC721MetadataInternal, ERC721OwnerInternal, ERC721TransferInternal, ERC721ApprovalInternal,
};

#[starknet::embeddable]
impl IERC721Abi<
    TContractState,
    impl ERC721Metadata: ERC721MetadataInternal<TContractState>,
    impl ERC721Owner: ERC721OwnerInternal<TContractState>,
    impl ERC721Transfer: ERC721TransferInternal<TContractState>,
    impl ERC721Approval: ERC721ApprovalInternal<TContractState>,
> of ERC721ABI<TContractState> {
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256 {
        ERC721Owner::balance_of(self, account)
    }
    fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress {
        ERC721Owner::owner_of(self, token_id)
    }
    fn safe_transfer_from(
        ref self: TContractState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>,
    ) {
        ERC721Transfer::safe_transfer_from(ref self, from, to, token_id, data);
    }
    fn transfer_from(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, token_id: u256,
    ) {
        ERC721Transfer::transfer_from(ref self, from, to, token_id);
    }
    fn approve(ref self: TContractState, to: ContractAddress, token_id: u256) {
        ERC721Approval::approve(ref self, to, token_id);
    }
    fn set_approval_for_all(ref self: TContractState, operator: ContractAddress, approved: bool) {
        ERC721Approval::set_approval_for_all(ref self, operator, approved);
    }
    fn get_approved(self: @TContractState, token_id: u256) -> ContractAddress {
        ERC721Approval::get_approved(self, token_id)
    }
    fn is_approved_for_all(
        self: @TContractState, owner: ContractAddress, operator: ContractAddress,
    ) -> bool {
        ERC721Approval::is_approved_for_all(self, owner, operator)
    }

    // IERC721Metadata
    fn name(self: @TContractState) -> ByteArray {
        ERC721Metadata::name(self)
    }
    fn symbol(self: @TContractState) -> ByteArray {
        ERC721Metadata::symbol(self)
    }
    fn token_uri(self: @TContractState, token_id: u256) -> ByteArray {
        ERC721Metadata::token_uri(self, token_id)
    }

    // IERC721CamelOnly
    fn balanceOf(self: @TContractState, account: ContractAddress) -> u256 {
        Self::balance_of(self, account)
    }
    fn ownerOf(self: @TContractState, tokenId: u256) -> ContractAddress {
        Self::owner_of(self, tokenId)
    }
    fn safeTransferFrom(
        ref self: TContractState,
        from: ContractAddress,
        to: ContractAddress,
        tokenId: u256,
        data: Span<felt252>,
    ) {
        Self::safe_transfer_from(ref self, from, to, tokenId, data);
    }

    fn transferFrom(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, tokenId: u256,
    ) {
        Self::transfer_from(ref self, from, to, tokenId);
    }
    fn setApprovalForAll(ref self: TContractState, operator: ContractAddress, approved: bool) {
        Self::set_approval_for_all(ref self, operator, approved);
    }
    fn getApproved(self: @TContractState, tokenId: u256) -> ContractAddress {
        Self::get_approved(self, tokenId)
    }
    fn isApprovedForAll(
        self: @TContractState, owner: ContractAddress, operator: ContractAddress,
    ) -> bool {
        Self::is_approved_for_all(self, owner, operator)
    }

    // IERC721MetadataCamelOnly
    fn tokenURI(self: @TContractState, tokenId: u256) -> ByteArray {
        Self::token_uri(self, tokenId)
    }
}
