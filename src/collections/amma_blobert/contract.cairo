use starknet::ContractAddress;


#[starknet::interface]
trait IAmmaBlobert<TContractState> {
    /// Gets the fighter associated with a Blobert token
    /// # Arguments
    /// * `token_id` - The unique identifier of the Blobert token
    /// # Returns
    /// * `u32` - The ID of the fighter associated with the Blobert token
    fn fighter(self: @TContractState, token_id: u256) -> u32;

    /// Gets the total number of fighters
    /// # Returns
    /// * `u32` - The total number of fighters in the contract
    fn number_of_fighters(self: @TContractState) -> u32;
}

#[starknet::interface]
trait IAmmaBlobertAdmin<TContractState> {
    fn set_n_fighters(ref self: TContractState, number_of_fighters: u32);
    fn mint(ref self: TContractState, owner: ContractAddress, fighter: u32);
}

pub fn get_amount_of_fighters(collection: ContractAddress) -> u32 {
    IAmmaBlobertDispatcher { contract_address: collection }.number_of_fighters()
}

#[dojo::model]
#[derive(Drop, Serde)]
struct AmmaBlobertTokenFighter {
    #[key]
    token_id: u256,
    fighter: u32,
}


#[starknet::contract]
mod amma_blobert_token {
    use core::poseidon::poseidon_hash_span;
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc721::{ERC721Component, ERC721HooksEmptyImpl, interface};
    use openzeppelin_upgrades::UpgradeableComponent;
    use openzeppelin_upgrades::interface::IUpgradeable;
    use sai_access::{Access, access_component};
    use starknet::storage::Map;
    use starknet::{ClassHash, ContractAddress, get_caller_address, get_contract_address};
    use torii_beacon::dojo::const_ns;
    use torii_beacon::dojo::traits::BeaconEmitterTrait;
    use torii_beacon::emitter::Registry;
    use torii_beacon::emitter_component;
    use crate::erc721;
    use crate::erc721::ERC721Internal;
    use super::{AmmaBlobertTokenFighter, IAmmaBlobert, IAmmaBlobertAdmin};

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
    const NAMESPACE_HASH: felt252 = bytearray_hash!("amma_blobert");
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
        number_of_fighters: u32,
        token_fighters: Map<u256, u32>,
        tokens_minted: u128,
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
            "Amma Blobert"
        }

        fn symbol(self: @ContractState) -> ByteArray {
            "AMMA"
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
    impl IAmmaBlobertImpl of IAmmaBlobert<ContractState> {
        fn fighter(self: @ContractState, token_id: u256) -> u32 {
            self.token_fighters.read(token_id)
        }
        fn number_of_fighters(self: @ContractState) -> u32 {
            self.number_of_fighters.read()
        }
    }

    #[abi(embed_v0)]
    impl IAmmaBlobertAdminImpl of IAmmaBlobertAdmin<ContractState> {
        fn set_n_fighters(ref self: ContractState, number_of_fighters: u32) {
            self.assert_caller_is_owner();
            assert(number_of_fighters >= self.number_of_fighters.read(), 'Cannot reduce fighters');
            self.number_of_fighters.write(number_of_fighters);
        }

        fn mint(ref self: ContractState, owner: ContractAddress, fighter: u32) {
            self.assert_caller_is_writer();
            self.mint_internal(owner, fighter);
        }
    }

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
            let token_id = self.tokens_minted.read() + 1;
            self.tokens_minted.write(token_id);
            let token_id: u256 = token_id.into();
            assert(
                fighter.is_non_zero() && fighter <= self.number_of_fighters.read(),
                'Invalid fighter ID',
            );
            self.emit_model(@AmmaBlobertTokenFighter { token_id, fighter });
            self.erc721.mint(owner, token_id);
            self.token_fighters.write(token_id, fighter);
            token_id
        }
    }
}
