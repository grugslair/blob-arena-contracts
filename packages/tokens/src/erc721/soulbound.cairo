use openzeppelin_introspection::interface::ISRC5_ID;
use openzeppelin_introspection::src5::SRC5Component;
use openzeppelin_token::erc721::ERC721Component::{
    HasComponent as ERC721HasComponent, InternalImpl as ERC721InternalImpl,
};
use openzeppelin_token::erc721::{ERC721Component, interface};
use starknet::ContractAddress;
use starknet::storage::StorageMapReadAccess;

mod Error {
    pub fn not_transferable<T>() -> T {
        panic!("Token is soulbound and not transferable")
    }
}

#[starknet::embeddable]
pub impl ERC721Soulbound<
    TContractState,
    impl MetadataInfo: super::ERC721MetadataInfo,
    impl SRC5: SRC5Component::HasComponent<TContractState>,
    +ERC721Component::HasComponent<TContractState>,
    +Drop<TContractState>,
    +ERC721Component::ERC721HooksTrait<TContractState>,
> of interface::ERC721ABI<TContractState> {
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256 {
        ERC721HasComponent::get_component(self).balance_of(account)
    }

    fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress {
        ERC721HasComponent::get_component(self).owner_of(token_id)
    }

    fn safe_transfer_from(
        ref self: TContractState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>,
    ) {
        Error::not_transferable()
    }

    fn transfer_from(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, token_id: u256,
    ) {
        Error::not_transferable()
    }

    fn approve(ref self: TContractState, to: ContractAddress, token_id: u256) {
        Error::not_transferable()
    }

    fn set_approval_for_all(ref self: TContractState, operator: ContractAddress, approved: bool) {
        Error::not_transferable()
    }

    fn get_approved(self: @TContractState, token_id: u256) -> ContractAddress {
        ERC721HasComponent::get_component(self).get_approved(token_id)
    }

    fn is_approved_for_all(
        self: @TContractState, owner: ContractAddress, operator: ContractAddress,
    ) -> bool {
        ERC721HasComponent::get_component(self).is_approved_for_all(owner, operator)
    }

    // IERC721Metadata
    fn name(self: @TContractState) -> ByteArray {
        MetadataInfo::name()
    }

    fn symbol(self: @TContractState) -> ByteArray {
        MetadataInfo::symbol()
    }

    fn token_uri(self: @TContractState, token_id: u256) -> ByteArray {
        format!("{}/{}", MetadataInfo::base_token_uri(), token_id).into()
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

    // ISRC5
    fn supports_interface(self: @TContractState, interface_id: felt252) -> bool {
        let sr5 = SRC5::get_component(self);
        if interface_id == ISRC5_ID {
            return true;
        }
        sr5.SRC5_supported_interfaces.read(interface_id)
    }
}

