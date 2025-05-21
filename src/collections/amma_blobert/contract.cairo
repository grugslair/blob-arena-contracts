use starknet::ContractAddress;

#[starknet::interface]
trait ERC721AmmaBlobert<TState> {
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

    // ISRC5
    fn supports_interface(self: @TState, interface_id: felt252) -> bool;

    // IERC721Metadata
    fn name(self: @TState) -> ByteArray;
    fn symbol(self: @TState) -> ByteArray;
    fn token_uri(self: @TState, token_id: u256) -> ByteArray;

    // IERC721CamelOnly
    fn balanceOf(
        self: @TState, account: ContractAddress,
    ) -> u256 {
        Self::balance_of(self, account)
    }
    fn ownerOf(self: @TState, tokenId: u256) -> ContractAddress {
        Self::owner_of(self, tokenId)
    }
    fn safeTransferFrom(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        tokenId: u256,
        data: Span<felt252>,
    ) {
        Self::safe_transfer_from(ref self, from, to, tokenId, data);
    }
    fn transferFrom(
        ref self: TState, from: ContractAddress, to: ContractAddress, tokenId: u256,
    ) {
        Self::transfer_from(ref self, from, to, tokenId);
    }
    fn setApprovalForAll(
        ref self: TState, operator: ContractAddress, approved: bool,
    ) {
        Self::set_approval_for_all(ref self, operator, approved);
    }
    fn getApproved(
        self: @TState, tokenId: u256,
    ) -> ContractAddress {
        Self::get_approved(self, tokenId)
    }
    fn isApprovedForAll(
        self: @TState, owner: ContractAddress, operator: ContractAddress,
    ) -> bool {
        Self::is_approved_for_all(self, owner, operator)
    }

    // IERC721MetadataCamelOnly
    fn tokenURI(self: @TState, tokenId: u256) -> ByteArray {
        Self::token_uri(self, tokenId)
    }
}


#[starknet::contract]
mod AmmaBlobert {
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use openzeppelin_upgrades::interface::IUpgradeable;
    use openzeppelin_upgrades::UpgradeableComponent;
    use starknet::{ClassHash, ContractAddress};
    use starknet::storage::Map;

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // External
    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;

    // Internal
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

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
    fn constructor(
        ref self: ContractState, beacon_address: ContractAddress, owner: ContractAddress,
    ) {
        self.erc721.initializer("MyToken", "MTK", "");
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}
