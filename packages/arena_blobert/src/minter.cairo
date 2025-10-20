use ba_blobert::{Seed, TokenTraits};
use ba_utils::{SeedProbability, felt252_to_u128};
use starknet::ContractAddress;

const BACKGROUND_COUNT: u128 = 8;
const ARMOUR_COUNT: u128 = 8;
const JEWELRY_COUNT: u128 = 8;
const WEAPON_COUNT: u128 = 8;
const MASK_COUNT: u128 = 8;

/// Main interface for Arena Blobert minting functionality
///
/// Provides public minting capabilities with rate limiting and supply controls.
/// Users can mint randomly generated Arena Blobert NFTs subject to time and quantity restrictions.
#[starknet::interface]
trait IArcadeBlobertMinter<TState> {
    /// Mints a new randomly generated Arena Blobert NFT for the caller
    ///
    /// Creates a new Arena Blobert with procedurally generated traits based on randomness.
    /// The NFT is minted directly to the caller's address with rate limiting and supply controls.
    ///
    /// # Returns
    /// * `u256` - The token ID of the newly minted Arena Blobert
    fn mint(ref self: TState) -> u256;


    fn claim_free_tokens(ref self: TState);

    fn tokens(self: @TState, user: ContractAddress) -> u64;

    fn max_bloberts(self: @TState) -> u64;

    fn free_tokens(self: @TState) -> u64;

    fn free_tokens_claimed(self: @TState, user: ContractAddress) -> bool;

    fn arcade_credit_cost(self: @TState) -> u128;
}

/// Administrative interface for Arena Blobert minter configuration
///
/// Provides owner-only functions to configure minting parameters and restrictions.
/// Controls the rate limiting and supply management for public minting.
#[starknet::interface]
trait IArcadeBlobertMinterAdmin<TState> {
    fn add_tokens(ref self: TState, user: ContractAddress, tokens: u64);

    /// Sets the maximum number of bloberts each address can own
    ///
    /// Configures the supply limit per address to prevent hoarding
    /// and ensure fair distribution of Arena Blobert NFTs.
    ///
    /// # Arguments
    /// * `max_bloberts` - Maximum number of bloberts per address
    ///
    /// # Access Control
    /// * Requires owner permissions
    fn set_max_bloberts(ref self: TState, max_bloberts: u64);
    fn set_free_tokens(ref self: TState, free_tokens: u64);
    fn set_arcade_credit_address(ref self: TState, contract_address: ContractAddress);
    fn set_arcade_credit_cost(ref self: TState, credit_cost: u128);
}

/// External interface for Arena Blobert NFT contract interaction
///
/// Defines the required functions that the minter needs from the main
/// Arena Blobert NFT contract to perform minting operations.
#[starknet::interface]
trait IArenaBlobert<TState> {
    /// Gets the number of Arena Blobert NFTs owned by an address
    ///
    /// # Arguments
    /// * `account` - The address to check the balance for
    ///
    /// # Returns
    /// * `u256` - Number of NFTs owned by the account
    fn balance_of(self: @TState, account: ContractAddress) -> u256;

    /// Mints a new Arena Blobert NFT with specified traits
    ///
    /// # Arguments
    /// * `owner` - The address to receive the newly minted NFT
    /// * `traits` - The trait configuration for the new NFT
    ///
    /// # Returns
    /// * `u256` - The token ID of the newly minted NFT
    fn mint(ref self: TState, owner: ContractAddress, traits: TokenTraits) -> u256;
}


fn generate_seed(randomness: felt252) -> Seed {
    let mut seed: u128 = felt252_to_u128(randomness);

    let background: u32 = seed.get_value(BACKGROUND_COUNT).try_into().unwrap();
    let armour: u32 = seed.get_value(ARMOUR_COUNT).try_into().unwrap();
    let jewelry: u32 = seed.get_value(JEWELRY_COUNT).try_into().unwrap();
    let weapon: u32 = seed.get_value(WEAPON_COUNT).try_into().unwrap();

    let mask_count = if armour <= 1 {
        8
    } else {
        MASK_COUNT // exclude the first two masks for other armours
    };
    let mask: u32 = seed.get_value(mask_count).try_into().unwrap();

    return Seed { background, armour, jewelry, mask, weapon };
}

#[derive(Drop, Serde, Introspect)]
struct Tokens {
    free_tokens_claimed: bool,
    tokens: u64,
}


#[starknet::contract]
mod arena_blobert_minter {
    use ba_blobert::TokenTraits;
    use ba_credit::arena_credit_consume_credits;
    use ba_utils::vrf::{VrfTrait, vrf_component};
    use beacon_library::{ToriiTable, register_table_with_schema};
    use sai_ownable::{OwnableTrait, ownable_component};
    use sai_return::emit_return;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address};
    use super::{
        IArcadeBlobertMinter, IArcadeBlobertMinterAdmin, IArenaBlobertDispatcher,
        IArenaBlobertDispatcherTrait, Tokens, generate_seed,
    };

    component!(path: ownable_component, storage: ownable, event: OwnableEvents);
    component!(path: vrf_component, storage: vrf, event: VrfEvents);

    const TABLE_HASH: felt252 = bytearrays_hash!("arena_blobert", "Tokens");
    impl Table = ToriiTable<TABLE_HASH>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: ownable_component::Storage,
        #[substorage(v0)]
        vrf: vrf_component::Storage,
        token_contract: IArenaBlobertDispatcher,
        credit_contract_address: ContractAddress,
        credit_cost: u128,
        tokens: Map<ContractAddress, u64>,
        free_claimed: Map<ContractAddress, bool>,
        max_bloberts: u64,
        free_tokens: u64,
        nonce: Map<ContractAddress, u64>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvents: ownable_component::Event,
        #[flat]
        VrfEvents: vrf_component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, owner: ContractAddress, token_address: ContractAddress,
    ) {
        self.grant_owner(owner);
        self.token_contract.write(IArenaBlobertDispatcher { contract_address: token_address });
        register_table_with_schema::<Tokens>("arena_blobert", "Token");
    }


    #[abi(embed_v0)]
    impl IOwnableImpl = ownable_component::OwnableImpl<ContractState>;

    #[abi(embed_v0)]
    impl IVrfImpl = vrf_component::VrfImpl<ContractState>;

    #[abi(embed_v0)]
    impl IArcadeBlobertMinterImpl of IArcadeBlobertMinter<ContractState> {
        fn mint(ref self: ContractState) -> u256 {
            let caller = get_caller_address();
            let randomness = self.get_nonce_seed(caller);
            let mut token_contract = self.token_contract.read();
            assert(
                self.max_bloberts.read() > token_contract.balance_of(caller).try_into().unwrap(),
                'Max bloberts reached',
            );
            let tokens = self.tokens.read(caller);
            if tokens > 0 {
                self.set_tokens(caller, tokens - 1);
            } else {
                arena_credit_consume_credits(
                    self.credit_contract_address.read(), caller, self.credit_cost.read(),
                );
            }

            emit_return(token_contract.mint(caller, TokenTraits::Seed(generate_seed(randomness))))
        }


        fn claim_free_tokens(ref self: ContractState) {
            let caller = get_caller_address();
            assert(!self.free_claimed.read(caller), 'Free tokens already claimed');
            let tokens = self.tokens.read(caller) + self.free_tokens.read();
            self.free_claimed.write(caller, true);
            self.tokens.write(caller, tokens);
            Table::set_entity(caller, @Tokens { free_tokens_claimed: true, tokens });
        }


        fn tokens(self: @ContractState, user: ContractAddress) -> u64 {
            self.tokens.read(user)
        }
        fn max_bloberts(self: @ContractState) -> u64 {
            self.max_bloberts.read()
        }
        fn free_tokens(self: @ContractState) -> u64 {
            self.free_tokens.read()
        }
        fn free_tokens_claimed(self: @ContractState, user: ContractAddress) -> bool {
            self.free_claimed.read(user)
        }
        fn arcade_credit_cost(self: @ContractState) -> u128 {
            self.credit_cost.read()
        }
    }

    #[abi(embed_v0)]
    impl IArcadeBlobertMinterAdminImpl of IArcadeBlobertMinterAdmin<ContractState> {
        fn add_tokens(ref self: ContractState, user: ContractAddress, tokens: u64) {
            self.assert_caller_is_owner();
            self.set_tokens(user, tokens + self.tokens.read(user));
        }
        fn set_max_bloberts(ref self: ContractState, max_bloberts: u64) {
            self.assert_caller_is_owner();
            self.max_bloberts.write(max_bloberts);
        }

        fn set_free_tokens(ref self: ContractState, free_tokens: u64) {
            self.assert_caller_is_owner();
            self.free_tokens.write(free_tokens);
        }
        fn set_arcade_credit_address(ref self: ContractState, contract_address: ContractAddress) {
            self.assert_caller_is_owner();
            self.credit_contract_address.write(contract_address);
        }
        fn set_arcade_credit_cost(ref self: ContractState, credit_cost: u128) {
            self.assert_caller_is_owner();
            self.credit_cost.write(credit_cost);
        }
    }

    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn set_tokens(ref self: ContractState, user: ContractAddress, tokens: u64) {
            self.tokens.write(user, tokens);
            Table::set_member(selector!("tokens"), user, @tokens);
        }
    }
}
