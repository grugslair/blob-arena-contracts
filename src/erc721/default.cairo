use super::traits::{
    ERC721MetadataInternal, ERC721OwnerInternal, ERC721TransferInternal, ERC721ApprovalInternal,
};
use openzeppelin_token::erc721::ERC721Component;
use openzeppelin_token::erc721::ERC721Component::{HasComponent, ERC721Metadata};
use openzeppelin_introspection::src5::SRC5Component;


impl ERC721MetadataDefault<
    TState,
    +HasComponent<TState>,
    +ERC721Component::ERC721HooksTrait<TState>,
    +SRC5Component::HasComponent<TState>,
> of ERC721MetadataInternal<TState> {
    fn name(self: @TState) -> ByteArray {
        ERC721Metadata::name(HasComponent::get_component(self))
    }

    fn symbol(self: @TState) -> ByteArray {
        ERC721Metadata::symbol(HasComponent::get_component(self))
    }

    fn token_uri(self: @TState, token_id: u256) -> ByteArray {
        ERC721Metadata::token_uri(HasComponent::get_component(self), token_id)
    }
}


impl ERC721OwnerDefault<
    TState,
    +HasComponent<TState>,
    +ERC721Component::ERC721HooksTrait<TState>,
    +SRC5Component::HasComponent<TState>,
> of ERC721OwnerInternal<TState> {
    fn balance_of(self: @TState, account: ContractAddress) -> u256 {
        ERC721Component::balance_of(HasComponent::get_component(self), account)
    }

    fn owner_of(self: @TState, token_id: u256) -> ContractAddress {
        ERC721Component::owner_of(HasComponent::get_component(self), token_id)
    }
}
impl ERC721TransferDefault<
    TState,
    +HasComponent<TState>,
    +ERC721Component::ERC721HooksTrait<TState>,
    +SRC5Component::HasComponent<TState>,
> of ERC721TransferInternal<TState> {
    fn safe_transfer_from(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>,
    ) {
        ERC721Component::safe_transfer_from(
            HasComponent::get_component(self), from, to, token_id, data,
        );
    }

    fn transfer_from(ref self: TState, from: ContractAddress, to: ContractAddress, token_id: u256) {
        ERC721Component::transfer_from(HasComponent::get_component(self), from, to, token_id);
    }
}
impl ERC721ApprovalDefault<
    TState,
    +HasComponent<TState>,
    +ERC721Component::ERC721HooksTrait<TState>,
    +SRC5Component::HasComponent<TState>,
> of ERC721ApprovalInternal<TState> {
    fn approve(ref self: TState, to: ContractAddress, token_id: u256) {
        ERC721Component::approve(HasComponent::get_component(self), to, token_id);
    }

    fn set_approval_for_all(ref self: TState, operator: ContractAddress, approved: bool) {
        ERC721Component::set_approval_for_all(
            HasComponent::get_component(self), operator, approved,
        );
    }

    fn get_approved(self: @TState, token_id: u256) -> ContractAddress {
        ERC721Component::get_approved(HasComponent::get_component(self), token_id)
    }

    fn is_approved_for_all(
        self: @TState, owner: ContractAddress, operator: ContractAddress,
    ) -> bool {
        ERC721Component::is_approved_for_all(HasComponent::get_component(self), owner, operator)
    }
}
