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
}

/// Administrative interface for Arena Blobert minter configuration
///
/// Provides owner-only functions to configure minting parameters and restrictions.
/// Controls the rate limiting and supply management for public minting.
#[starknet::interface]
trait IArcadeBlobertMinterAdmin<TState> {
    /// Sets the minimum time between mints for each address
    ///
    /// Configures the cooldown period that must elapse before an address
    /// can mint another Arena Blobert NFT.
    ///
    /// # Arguments
    /// * `min_mint_time` - Cooldown period in seconds between mints
    ///
    /// # Access Control
    /// * Requires owner permissions
    fn set_min_mint_time(ref self: TState, min_mint_time: u64);

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
    fn set_max_bloberts(ref self: TState, max_bloberts: u32);
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
struct LastMint {
    last_mint: u64,
}

#[starknet::contract]
mod arena_blobert_minter {
    use ba_blobert::TokenTraits;
    use ba_utils::uuid;
    use beacon_library::{ToriiTable, register_table_with_schema};
    use sai_ownable::{OwnableTrait, ownable_component};
    use sai_return::emit_return;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use super::{
        IArcadeBlobertMinter, IArcadeBlobertMinterAdmin, IArenaBlobertDispatcher,
        IArenaBlobertDispatcherTrait, LastMint, generate_seed,
    };

    component!(path: ownable_component, storage: ownable, event: OwnableEvents);

    const LAST_MINT_TABLE_ID: felt252 = bytearrays_hash!("arena_blobert", "LastMint");
    impl LastMintTable = ToriiTable<LAST_MINT_TABLE_ID>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: ownable_component::Storage,
        token_contract: IArenaBlobertDispatcher,
        last_mint: Map<ContractAddress, u64>,
        min_mint_time: u64,
        max_bloberts: u32,
        nonce: Map<ContractAddress, u64>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvents: ownable_component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, owner: ContractAddress, token_address: ContractAddress,
    ) {
        self.grant_owner(owner);
        self.token_contract.write(IArenaBlobertDispatcher { contract_address: token_address });
        register_table_with_schema::<LastMint>("arena_blobert", "LastMint");
    }


    #[abi(embed_v0)]
    impl IOwnableImpl = ownable_component::OwnableImpl<ContractState>;

    #[abi(embed_v0)]
    impl IArcadeBlobertMinterImpl of IArcadeBlobertMinter<ContractState> {
        fn mint(ref self: ContractState) -> u256 {
            let timestamp = get_block_timestamp();

            let caller = get_caller_address();
            // TODO: make randomness
            let randomness = uuid();
            let mut token_contract = self.token_contract.read();
            assert(
                self.last_mint.read(caller) + self.min_mint_time.read() <= timestamp,
                'Cannot mint yet',
            );
            assert(
                self.max_bloberts.read() > token_contract.balance_of(caller).try_into().unwrap(),
                'Max bloberts reached',
            );
            self.last_mint.write(caller, timestamp);
            LastMintTable::set_entity(caller, @timestamp);

            emit_return(token_contract.mint(caller, TokenTraits::Seed(generate_seed(randomness))))
        }
    }

    #[abi(embed_v0)]
    impl IArcadeBlobertMinterAdminImpl of IArcadeBlobertMinterAdmin<ContractState> {
        fn set_min_mint_time(ref self: ContractState, min_mint_time: u64) {
            self.ownable.caller_is_owner();
            self.min_mint_time.write(min_mint_time);
        }
        fn set_max_bloberts(ref self: ContractState, max_bloberts: u32) {
            self.ownable.caller_is_owner();
            self.max_bloberts.write(max_bloberts);
        }
    }
}
