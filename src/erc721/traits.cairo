use starknet::ContractAddress;

trait ERC721MetadataInternal<TState> {
    fn name(self: @TState) -> ByteArray;
    fn symbol(self: @TState) -> ByteArray;
    fn token_uri(self: @TState, token_id: u256) -> ByteArray;
}

trait ERC721OwnerInternal<TState> {
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
    fn owner_of(self: @TState, token_id: u256) -> ContractAddress;
}

trait ERC721TransferInternal<TState> {
    fn safe_transfer_from(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>,
    );
    fn transfer_from(ref self: TState, from: ContractAddress, to: ContractAddress, token_id: u256);
}

trait ERC721ApprovalInternal<TState> {
    fn approve(ref self: TState, to: ContractAddress, token_id: u256);
    fn set_approval_for_all(ref self: TState, operator: ContractAddress, approved: bool);
    fn get_approved(self: @TState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(
        self: @TState, owner: ContractAddress, operator: ContractAddress,
    ) -> bool;
}

trait ERC721Internal<TState> {
    // IERC721Metadata
    fn name(self: @TState) -> ByteArray;
    fn symbol(self: @TState) -> ByteArray;
    fn token_uri(self: @TState, token_id: u256) -> ByteArray;

    // IERC721
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
    fn owner_of(self: @TState, token_id: u256) -> ContractAddress;
    fn safe_transfer_from(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>,
    );
    fn transfer_from(ref self: TState, from: ContractAddress, to: ContractAddress, token_id: u256);
    fn approve(ref self: TState, to: ContractAddress, token_id: u256);
    fn set_approval_for_all(ref self: TState, operator: ContractAddress, approved: bool);
    fn get_approved(self: @TState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(
        self: @TState, owner: ContractAddress, operator: ContractAddress,
    ) -> bool;
}

impl ERC721InternalImpl<
    TState,
    impl ERC721Metadata: ERC721MetadataInternal<TState>,
    impl ERC721Owner: ERC721OwnerInternal<TState>,
    impl ERC721Transfer: ERC721TransferInternal<TState>,
    impl ERC721Approval: ERC721ApprovalInternal<TState>,
> of ERC721Internal<TState> {
    fn name(self: @TState) -> ByteArray {
        ERC721Metadata::name(self)
    }

    fn symbol(self: @TState) -> ByteArray {
        ERC721Metadata::symbol(self)
    }

    fn token_uri(self: @TState, token_id: u256) -> ByteArray {
        ERC721Metadata::token_uri(self, token_id)
    }

    fn balance_of(self: @TState, account: ContractAddress) -> u256 {
        ERC721Owner::balance_of(self, account)
    }

    fn owner_of(self: @TState, token_id: u256) -> ContractAddress {
        ERC721Owner::owner_of(self, token_id)
    }

    fn safe_transfer_from(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>,
    ) {
        ERC721Transfer::safe_transfer_from(ref self, from, to, token_id, data);
    }

    fn transfer_from(ref self: TState, from: ContractAddress, to: ContractAddress, token_id: u256) {
        ERC721Transfer::transfer_from(ref self, from, to, token_id);
    }

    fn approve(ref self: TState, to: ContractAddress, token_id: u256) {
        ERC721Approval::approve(ref self, to, token_id);
    }

    fn set_approval_for_all(ref self: TState, operator: ContractAddress, approved: bool) {
        ERC721Approval::set_approval_for_all(ref self, operator, approved);
    }

    fn get_approved(self: @TState, token_id: u256) -> ContractAddress {
        ERC721Approval::get_approved(self, token_id)
    }

    fn is_approved_for_all(
        self: @TState, owner: ContractAddress, operator: ContractAddress,
    ) -> bool {
        ERC721Approval::is_approved_for_all(self, owner, operator)
    }
}

