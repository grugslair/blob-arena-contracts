use starknet::ContractAddress;
use super::super::attributes::{Seed, TokenAttributes};
/// Interface for the FreeBlobert NFT contract
///
/// # Interface Functions
///
/// * `mint` - Mints a random Blobert NFT and returns its token ID
///    Returns:
///    * `u256` - The ID of the newly minted token
///
///    Models:
///    * BlobertToken
///
/// * `traits` - Retrieves the attributes/traits of a specific Blobert NFT
///    Parameters:
///    * `token_id` - The ID of the token to query
///    Returns:
///    * `TokenAttributes` - The attributes associated with the token
#[starknet::interface]
trait IFreeBlobert<TContractState> {
    fn burn(ref self: TContractState, token_id: u256);
    fn traits(self: @TContractState, token_id: u256) -> TokenAttributes;
}

#[starknet::interface]
trait IFreeBlobertAdmin<TContractState> {
    fn mint(ref self: TContractState, owner: ContractAddress, attributes: TokenAttributes) -> u256;
}


#[dojo::model]
#[derive(Copy, Drop, Serde, PartialEq)]
struct ArenaBlobertToken {
    #[key]
    token_id: u256,
    attributes: TokenAttributes,
}

#[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
enum TokenType {
    #[default]
    NotMinted,
    Seed,
    Custom,
}


#[starknet::contract]
mod arena_blobert_actions {
    use core::poseidon::poseidon_hash_span;
    use dojo_beacon::dojo::const_ns;
    use dojo_beacon::dojo::traits::BeaconEmitterTrait;
    use dojo_beacon::emitter::Registry;
    use dojo_beacon::emitter_component;
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc721::{ERC721Component, ERC721HooksEmptyImpl, interface};
    use openzeppelin_upgrades::UpgradeableComponent;
    use openzeppelin_upgrades::interface::IUpgradeable;
    use sai_access::{Access, access_component};
    use starknet::storage::Map;
    use starknet::{ClassHash, ContractAddress, get_caller_address, get_contract_address};
    use crate::erc721;
    use crate::erc721::ERC721Internal;
    use super::{IFreeBlobert, IFreeBlobertAdmin, Seed, TokenAttributes, TokenType};

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: emitter_component, storage: emitter, event: EmitterEvents);
    component!(path: access_component, storage: access, event: AccessEvents);


    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    // #[abi(embed_v0)]
    impl ERC721Abi = erc721::IERC721Abi<ContractState, ERC721>;

    #[abi(embed_v0)]
    impl AccessImpl = access_component::AccessImpl<ContractState>;

    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    // Internal
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;
    const NAMESPACE_HASH: felt252 = bytearray_hash!("arena_blobert");
    impl Emitter = const_ns::ConstNsBeaconEmitter<NAMESPACE_HASH, ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        emitter: emitter_component::Storage,
        #[substorage(v0)]
        access: access_component::Storage,
        token_seeds: Map<u256, Seed>,
        token_customs: Map<u256, felt252>,
        tokens_minted: u128,
        token_types: Map<u256, TokenType>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        EmitterEvents: emitter_component::Event,
        #[flat]
        AccessEvents: access_component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.erc721.initializer_no_metadata();
        self.grant_owner(owner);
        self.src5.register_interface(interface::IERC721_METADATA_ID);
    }


    impl ERC721 of ERC721Internal<ContractState> {
        fn name(self: @ContractState) -> ByteArray {
            "Arena Blobert"
        }

        fn symbol(self: @ContractState) -> ByteArray {
            "BABLOB"
        }

        fn token_uri(self: @ContractState, token_id: u256) -> ByteArray {
            self.erc721._require_owned(token_id);
            format!("http://example.com/{}", token_id)
        }

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
    impl IFreeBlobertImpl of IFreeBlobert<ContractState> {
        fn burn(ref self: ContractState, token_id: u256) {
            self.erc721.burn(token_id);
        }
    }

    #[abi(embed_v0)]
    impl IFreeBlobertAdminImpl of IFreeBlobertAdmin<ContractState> {}

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.assert_caller_is_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn mint_internal(ref self: ContractState, owner: ContractAddress, fighter: u32) -> u256 {
            let minted = self.tokens_minted.read() + 1;
            self.tokens_minted.write(minted);
            let token_id: u256 = minted.into() + 4844;
            self.emit_model(@AmmaBlobertTokenFighter { token_id, fighter });
            self.erc721.mint(owner, token_id);
            self.token_fighters.write(token_id, fighter);
            token_id
        }

        fn caller_is_token_owner(self: @ContractState, token_id: u256) {
            assert(
                get_caller_address() == self.erc721._owner_of(token_id),
                'Caller is not the token owner',
            );
        }
    }
}

