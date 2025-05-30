use super::internal::ERC721Internal;


fn transfer_panic<T>() -> T {
    panic!("Not transferable")
}

impl ERC721TransferSoulbound<TState> of ERC721TransferInternal<TState> {
    fn safe_transfer_from(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>,
    ) {
        transfer_panic();
    }

    fn transfer_from(ref self: TState, from: ContractAddress, to: ContractAddress, token_id: u256) {
        transfer_panic();
    }
}

impl ERC721ApprovalSoulbound<TState> of ERC721ApprovalInternal<TState> {
    fn approve(ref self: TState, to: ContractAddress, token_id: u256) {
        transfer_panic();
    }

    fn set_approval_for_all(ref self: TState, operator: ContractAddress, approved: bool) {
        transfer_panic();
    }

    fn get_approved(self: @TState, token_id: u256) -> ContractAddress {
        transfer_panic();
    }

    fn is_approved_for_all(
        self: @TState, owner: ContractAddress, operator: ContractAddress,
    ) -> bool {
        transfer_panic();
    }
}
