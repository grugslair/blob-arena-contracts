use starknet::ContractAddress;


#[starknet::interface]
trait IAmmaBlobert<TContractState> {
    /// Mints a free Blobert token
    /// # Returns
    /// * `Array<u256>` - An array containing the token id(s) of the minted Blobert(s)
    fn mint_free(ref self: TContractState) -> Array<u256>;
    /// Mints a Blobert token using an arcade unlock attempt
    /// # Arguments
    /// * `attempt_id` - The unique identifier for the arcade attempt that was won
    /// # Returns
    /// * `u256` - The token id of the minted Blobert
    fn mint_arcade_unlock(ref self: TContractState, attempt_id: felt252) -> u256;
}

#[starknet::interface]
trait IAmmaBlobertFighters<TContractState> {
    /// Creates a new fighter with the given attributes
    /// # Arguments
    /// * `name` - Name of the fighter
    /// * `stats` - Base statistics of the fighter
    /// * `generated_stats` - stats of the fighter used when generating
    /// * `attacks` - Array of attacks available to the fighter either a tag, attack input or attack
    /// id # Returns
    /// * `u32` - ID of the newly created fighter
    ///
    /// Models:
    /// * AmmaFighter
    ///
    /// Events:
    /// * AmmaFighterName
    fn new_fighter(
        ref self: TContractState,
        name: ByteArray,
        stats: UStats,
        generated_stats: UStats,
        attacks: Array<IdTagNew<AttackInput>>,
    ) -> u32;

    /// Updates an existing fighter's attributes
    /// # Arguments
    /// * `fighter` - ID of the fighter to update
    /// * `name` - New name for the fighter
    /// * `stats` - New base statistics for the fighter
    /// * `generated_stats` - New generated statistics for the fighter
    /// * `attacks` - Array of attacks available to the fighter either a tag, attack input or attack
    /// id
    ///
    /// Models:
    /// * AmmaFighter
    ///
    /// Events:
    /// * AmmaFighterName
    fn set_fighter(
        ref self: TContractState,
        fighter: u32,
        name: ByteArray,
        stats: UStats,
        generated_stats: UStats,
        attacks: Array<IdTagNew<AttackInput>>,
    );

    /// Updates a fighter's base statistics
    /// # Arguments
    /// * `fighter` - ID of the fighter to update
    /// * `stats` - New statistics to set
    ///
    /// Models:
    /// * AmmaFighter
    fn set_fighter_stats(ref self: TContractState, fighter: u32, stats: UStats);

    /// Updates a fighter's generated statistics
    /// # Arguments
    /// * `fighter` - ID of the fighter to update
    /// * `stats` - New generated statistics to set
    ///
    /// Models:
    /// * AmmaFighter
    fn set_fighter_generated_stats(ref self: TContractState, fighter: u32, stats: UStats);

    /// Updates a fighter's available attacks
    /// # Arguments
    /// * `fighter` - ID of the fighter to update
    /// * `attacks` - New array of attacks to set
    ///
    /// Models:
    /// * AmmaFighter
    fn set_fighter_attacks(
        ref self: TContractState, fighter: u32, attacks: Array<IdTagNew<AttackInput>>,
    );

    /// Updates a fighter's name
    /// # Arguments
    /// * `fighter` - ID of the fighter to update
    /// * `name` - New name to set
    ///
    /// Events:
    /// * AmmaFighterName
    fn set_fighter_name(ref self: TContractState, fighter: u32, name: ByteArray);

    /// Gets the total number of fighters
    /// # Returns
    /// * `u32` - Total number of fighters
    fn amount_of_fighters(self: @TContractState) -> u32;

    /// Sets the total number of fighters
    /// # Arguments
    /// * `amount` - New total number of fighters to set
    fn set_amount_of_fighters(ref self: TContractState, amount: u32);

    /// Mints a Blobert token without unlock
    /// # Arguments
    /// * `player` - Contract address of the player to mint the token for
    /// * `fighter` - ID of the fighter to mint
    /// # Returns
    /// * `u256` - The token ID of the minted Blobert
    fn admin_mint(ref self: TContractState, player: ContractAddress, fighter: u32) -> u256;
}


fn get_amount_of_fighters(contract_address: ContractAddress) -> u32 {
    IAmmaBlobertFightersDispatcher { contract_address }.amount_of_fighters()
}

#[starknet::contract]
mod AmmaBlobert {
    use core::poseidon::poseidon_hash_span;
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc721::{ERC721Component, ERC721HooksEmptyImpl, interface};
    use openzeppelin_upgrades::UpgradeableComponent;
    use openzeppelin_upgrades::interface::IUpgradeable;
    use starknet::storage::Map;
    use starknet::{ClassHash, ContractAddress, get_caller_address, get_contract_address};
    use crate::erc721;
    use crate::erc721::ERC721Internal;
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl =
        OwnableComponent::OwnableTwoStepMixinImpl<ContractState>;

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[abi(embed_v0)]
    impl ERC721Abi = erc721::IERC721Abi<ContractState, ERC721>;

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
        fighters: Map<felt252, bool>,
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
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }

        fn admin_mint(ref self: ContractState, player: ContractAddress, fighter: u32) -> u256 {
            let mut storage = self.storage(AMMA_BLOBERT_NAMESPACE_HASH);
            storage.assert_caller_has_permission(Role::CollectionMinter);
            let token_id = uuid().into();
            storage.set_blobert_token(token_id, player, TokenAttributes::Custom(fighter.into()));
            return_value(token_id)
        }
    }
}
