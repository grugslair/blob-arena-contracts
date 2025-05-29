use starknet::ContractAddress;


#[starknet::contract]
mod AmmaBlobert {
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc721::{ERC721Component, ERC721HooksEmptyImpl, interface};
    use openzeppelin_upgrades::interface::IUpgradeable;
    use openzeppelin_upgrades::UpgradeableComponent;
    use starknet::{ClassHash, ContractAddress, get_caller_address};
    use starknet::storage::Map;

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl =
        OwnableComponent::OwnableTwoStepMixinImpl<ContractState>;


    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    // Internal
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        token_fighters: Map<u256, felt252>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, beacon: ContractAddress, owner: ContractAddress) {
        self.erc721.initializer_no_metadata();
        self.ownable.initializer(owner);
        self.src5.register_interface(interface::IERC721_METADATA_ID);
    }

    #[abi(embed_v0)]
    impl ERC721Metadata of interface::IERC721Metadata<ContractState> {
        fn name(self: @ContractState) -> ByteArray {
            "Amma Blobert"
        }

        fn symbol(self: @ContractState) -> ByteArray {
            "AMMA"
        }

        fn token_uri(self: @ContractState, token_id: u256) -> ByteArray {
            self.erc721._require_owned(token_id);
            format!("http://example.com/{}", token_id)
        }
    }

    #[abi(embed_v0)]
    impl ERC721 of interface::IERC721<ContractState> {
        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            ERC721Impl::balance_of(self, account)
        }

        fn owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
            ERC721Impl::owner_of(self, token_id)
        }

        fn safe_transfer_from(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256,
            data: Span<felt252>,
        ) {
            panic!("Not currently transferable")
        }

        fn transfer_from(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256,
        ) {
            panic!("Not currently transferable")
        }

        fn approve(ref self: ContractState, to: ContractAddress, token_id: u256) {
            panic!("Not currently transferable")
        }

        fn set_approval_for_all(
            ref self: ContractState, operator: ContractAddress, approved: bool,
        ) {
            panic!("Not currently transferable")
        }

        fn get_approved(self: @ContractState, token_id: u256) -> ContractAddress {
            ERC721Impl::get_approved(self, token_id)
        }

        fn is_approved_for_all(
            self: @ContractState, owner: ContractAddress, operator: ContractAddress,
        ) -> bool {
            ERC721Impl::is_approved_for_all(self, owner, operator)
        }
    }

    #[abi(embed_v0)]
    impl ERC721CamelOnly of interface::IERC721CamelOnly<ContractState> {
        fn balanceOf(self: @ContractState, account: ContractAddress) -> u256 {
            ERC721::balance_of(self, account)
        }

        fn ownerOf(self: @ContractState, tokenId: u256) -> ContractAddress {
            ERC721::owner_of(self, tokenId)
        }

        fn safeTransferFrom(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            tokenId: u256,
            data: Span<felt252>,
        ) {
            ERC721::safe_transfer_from(ref self, from, to, tokenId, data)
        }

        fn transferFrom(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, tokenId: u256,
        ) {
            ERC721::transfer_from(ref self, from, to, tokenId)
        }

        fn setApprovalForAll(ref self: ContractState, operator: ContractAddress, approved: bool) {
            ERC721::set_approval_for_all(ref self, operator, approved)
        }

        fn getApproved(self: @ContractState, tokenId: u256) -> ContractAddress {
            ERC721::get_approved(self, tokenId)
        }

        fn isApprovedForAll(
            self: @ContractState, owner: ContractAddress, operator: ContractAddress,
        ) -> bool {
            ERC721::is_approved_for_all(self, owner, operator)
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}
