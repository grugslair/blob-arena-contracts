use starknet::ContractAddress;
use crate::stats::UStats;
use crate::arcade::ArcadeOpponentInput;
use crate::collections::{TokenAttributes, BlobertItemKey};
use crate::tags::IdTagNew;
use crate::attacks::components::AttackInput;
use super::{ArcadeGame, ArcadeChallengeAttempt, ArcadePhase, ArcadeOpponent};

#[starknet::interface]
trait IArcade<TContractState> {
    /// Executes an attack move in an active game.
    /// # Arguments
    /// * `game_id` - The unique identi`fier of the active game
    /// * `attack_id` - The ID of the attack move to execute
    ///
    /// Models:
    /// - CombatantState
    /// - ArcadeGame
    /// - AttackLastUsed
    ///
    /// Events:
    /// - RoundResult
    fn attack(ref self: TContractState, game_id: felt252, attack_id: felt252);

    /// Initiates a new challenge attempt.
    /// # Arguments
    /// * `challenge_id` - The unique identifier of the challenge to attempt
    /// * `collection_address` - The contract address of the NFT collection
    /// * `token_id` - The token ID of the NFT being used
    /// * `attacks` - Array of attack tuples (attack_id, attack_power)
    ///
    /// Models:
    /// - ArcadeFreeGames
    /// - ArcadePaidGames
    /// - AttackAvailable
    /// - CombatantToken
    /// - CombatantState
    /// - ArcadeGame
    /// - ArcadeChallengeAttempt
    /// - ArcadeStageGame
    fn start_challenge(
        ref self: TContractState,
        challenge_id: felt252,
        collection_address: ContractAddress,
        token_id: u256,
        attacks: Array<(felt252, felt252)>,
    ) -> (felt252, felt252);

    /// Advances to the next round in an active challenge.
    /// # Arguments
    /// * `attempt_id` - The unique identifier of the challenge attempt
    ///
    /// Models:
    /// - AttackAvailable
    /// - CombatantState
    /// - ArcadeGame
    /// - ArcadeChallengeAttempt
    /// - ArcadeStageGame
    fn next_challenge_round(ref self: TContractState, attempt_id: felt252) -> felt252;

    /// Restarts a challenge attempt from the beginning.
    /// # Arguments
    /// * `attempt_id` - The unique identifier of the challenge attempt to respawn
    ///
    /// Models:
    /// - ArcadeFreeGames
    /// - ArcadePaidGames
    /// - AttackAvailable
    /// - CombatantState
    /// - ArcadeGame
    /// - ArcadeChallengeAttempt
    /// - ArcadeStageGame
    ///
    /// Events:
    /// - ArcadeChallengeRespawn
    fn respawn_challenge(ref self: TContractState, attempt_id: felt252) -> felt252;

    /// Completes and finalizes an active challenge attempt.
    /// # Arguments
    /// * `attempt_id` - The unique identifier of the challenge attempt to end
    ///
    /// Models:
    /// - ArcadeChallengeAttempt
    /// - ArcadeStageGame
    fn end_challenge(ref self: TContractState, attempt_id: felt252);

    /// Gets the challenge attemt
    ///
    /// # Arguments
    /// * `attempt_id` - The unique identifier of the challenge attempt
    ///
    /// Returns:
    /// - `ArcadeChallengeAttempt` - The challenge attempt object
    fn challenge_attempt(self: @TContractState, attempt_id: felt252) -> ArcadeChallengeAttempt;

    /// Gets a arcade game
    /// # Arguments
    /// * `game_id` - The unique identifier of the game
    ///
    /// Returns:
    /// - `ArcadeGame` - The game object
    fn game(self: @TContractState, game_id: felt252) -> ArcadeGame;

    /// Returns the game details for a given challenge attempt
    /// # Arguments
    /// * `attempt_id` - The unique identifier of an attempt
    /// # Returns
    /// * `ArcadeGame` - The game details for the specified attempt
    fn challenge_attempt_game(self: @TContractState, attempt_id: felt252) -> ArcadeGame;

    /// Returns the current game phase for a given game
    /// # Arguments
    /// * `game_id` - The unique identifier of a game
    /// # Returns
    /// * `ArcadePhase` - The current phase of the specified game
    fn game_phase(self: @TContractState, game_id: felt252) -> ArcadePhase;

    /// Retrieves the challenge ID associated with a specific tag
    /// # Arguments
    /// * `tag` - The tag to look up
    /// # Returns
    /// * `felt252` - The challenge ID associated with the tag
    fn challenge_id_from_tag(self: @TContractState, tag: ByteArray) -> felt252;

    /// Retrieves the opponent token associated with a specific ID
    /// # Arguments
    /// * `opponent_id` - The ID of the opponent
    /// # Returns
    /// * `ArcadeOpponent` - The opponent token associated with the ID
    fn opponent_token(self: @TContractState, opponent_id: felt252) -> ArcadeOpponent;
    /// Retrieves the stats of a specific opponent
    /// # Arguments
    /// * `opponent_id` - The ID of the opponent
    /// # Returns
    /// * `UStats` - The stats of the opponent
    fn opponent_stats(self: @TContractState, opponent_id: felt252) -> UStats;
    /// Retrieves the attacks of a specific opponent
    /// # Arguments
    /// * `opponent_id` - The ID of the opponent
    /// # Returns
    /// * `Array<felt252>` - The attacks of the opponent
    fn opponent_attacks(self: @TContractState, opponent_id: felt252) -> Array<felt252>;
    /// Retrieves the current challenge attempt ID for a player
    /// # Arguments
    /// * `player` - The contract address of the player
    /// * `collection_address` - The contract address of the NFT collection
    /// * `token_id` - The token ID of the NFT being used
    /// # Returns
    /// * `felt252` - The current challenge attempt ID for the player
    fn current_challenge_attempt_id(
        self: @TContractState,
        player: ContractAddress,
        collection_address: ContractAddress,
        token_id: u256,
    ) -> felt252;
    /// Retrieves the current challenge attempt ID for a caller
    /// # Arguments
    /// * `collection_address` - The contract address of the NFT collection
    /// * `token_id` - The token ID of the NFT being used
    /// # Returns
    /// * `felt252` - The current challenge attempt ID for the caller
    fn callers_current_challenge_attempt_id(
        self: @TContractState, collection_address: ContractAddress, token_id: u256,
    ) -> felt252;

    /// Gets the price of game tokens in micro USD
    /// # Arguments
    /// * `amount` - The number of game tokens to get the price for
    /// # Returns
    /// * `u128` - The price of a single game token in micro USD
    fn get_game_token_micro_usd_price(self: @TContractState, amount: u32) -> u128;

    /// Gets the price of game tokens in the current contract
    /// # Arguments
    /// * `erc20_address` - The contract address of the ERC20 token used for payments
    /// * `amount` - The number of game tokens to get the price for
    /// # Returns
    /// * `u256` - The price of the specified amount of game tokens
    fn get_game_tokens_price(
        self: @TContractState, erc20_address: ContractAddress, amount: u32,
    ) -> u256;

    /// Purchases game tokens for the caller
    /// # Arguments
    /// * `erc20_address` - The contract address of the ERC20 token used for payments
    /// * `amount` - The number of game tokens to purchase
    fn purchase_game_tokens(ref self: TContractState, erc20_address: ContractAddress, amount: u32);
}

/// Interface for managing Arcade (Player vs Environment) administrative functions.
#[starknet::interface]
trait IArcadeAdmin<TContractState> {
    /// Creates a new opponent with specified attributes and allowed collections
    /// # Arguments
    /// * `name` - Name of the opponent
    /// * `collection` - Contract address of opponent's collection
    /// * `attributes` - Token attributes for the opponent (for off chain generation)
    /// * `stats` - Base stats for the opponent
    /// * `attacks` - Array of attacks available to the opponent
    /// * `collections_allowed` - Array of collection addresses that can challenge this opponent
    ///
    /// Models:
    /// - Tag
    /// - Attack
    /// - ArcadeOpponent
    /// - ArcadeCollectionAllowed
    ///
    /// Events:
    /// - AttackName
    /// - ArcadeBlobertInfo
    fn new_opponent(
        ref self: TContractState,
        name: ByteArray,
        collection: ContractAddress,
        attributes: TokenAttributes,
        stats: UStats,
        attacks: Array<IdTagNew<AttackInput>>,
    ) -> felt252;

    /// Creates a new Arcade challenge with defined opponents and collection restrictions
    /// # Arguments
    /// * `name` - Name of the challenge
    /// * `health_recovery_pc` - Health recovery percentage between fights
    /// * `opponents` - Array of opponents in the challenge
    /// * `collections_allowed` - Collections that can participate in this challenge
    ///
    /// Models:
    /// - Tag
    /// - Attack
    /// - ArcadeOpponent
    /// - ArcadeCollectionAllowed
    /// - ArcadeChallenge
    /// - ArcadeStageOpponent
    ///
    /// Events:
    /// - AttackName
    /// - ArcadeBlobertInfo
    /// - ArcadeChallengeName
    ///
    fn new_challenge(
        ref self: TContractState,
        name: ByteArray,
        health_recovery_pc: u8,
        opponents: Array<IdTagNew<ArcadeOpponentInput>>,
        collections_allowed: Array<ContractAddress>,
    ) -> felt252;

    /// Sets availability of a single collection for a specific ID
    /// # Arguments
    /// * `id` - Target ID to modify
    /// * `collection` - Collection address to set
    /// * `available` - Whether collection should be available
    ///
    /// Models:
    /// - ArcadeCollectionAllowed
    ///
    fn set_collection(
        ref self: TContractState, id: felt252, collection: ContractAddress, available: bool,
    );

    /// Sets availability of multiple collections for a specific ID
    /// # Arguments
    /// * `id` - Target ID to modify
    /// * `collections` - Array of collection addresses
    /// * `available` - Whether collections should be available
    ///
    /// Models:
    /// - ArcadeCollectionAllowed
    fn set_collections(
        ref self: TContractState, id: felt252, collections: Array<ContractAddress>, available: bool,
    );

    /// Sets availability of a collection for multiple IDs
    /// # Arguments
    /// * `ids` - Array of IDs to modify
    /// * `collection` - Collection address to set
    /// * `available` - Whether collection should be available
    ///
    /// Models:
    /// - ArcadeCollectionAllowed
    fn set_ids_collection(
        ref self: TContractState, ids: Array<felt252>, collection: ContractAddress, available: bool,
    );

    /// Mints paid game passes for a player
    /// # Arguments
    /// * `player` - Address of player receiving games
    /// * `amount` - Number of paid games to mint
    ///
    /// Models:
    /// - ArcadePaidGames
    fn mint_paid_games(ref self: TContractState, player: ContractAddress, amount: u32);

    /// Gets the current contract address for the Pragma ABI dispatcher
    /// # Arguments
    /// * `contract_address` - The address of the Pragma ABI dispatcher contract``
    fn set_pragma_contract_address(ref self: TContractState, contract_address: ContractAddress);

    /// Sets the price pair for a specific ERC20 token
    /// # Arguments
    /// * `erc20_address` - The contract address of the ERC20 token
    /// * `price_pair` - The price pair identifier for the token ('LORDS/USD')
    fn set_price_pair(
        ref self: TContractState, erc20_address: ContractAddress, price_pair: felt252,
    );
    /// Sets the price of game tokens in micro USD
    /// # Arguments
    /// * `price` - The price of a single game token in micro USD
    fn set_token_micro_usd_price(ref self: TContractState, price: u128);
    /// Set wallet address for payments
    /// # Arguments
    /// * `wallet_address` - The contract address of the wallet to receive payments
    fn set_wallet_address(ref self: TContractState, wallet_address: ContractAddress);
}


#[dojo::contract]
mod arcade_actions {
    use core::num::traits::Pow;
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::storage::Map;
    use dojo::world::WorldStorage;
    use crate::arcade::{
        ArcadeTrait, ArcadeStorage, ARCADE_NAMESPACE_HASH, ArcadeStore, ArcadeOpponentInput,
        ArcadeChallengeAttempt, ArcadeGame, ArcadePhase, CHALLENGE_TAG_GROUP, ArcadeOpponent,
    };
    use pragma_lib::abi::{
        IPragmaABIDispatcher, IPragmaABIDispatcherTrait, PragmaPricesResponse, DataType,
    };
    use openzeppelin_token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use crate::attacks::{AttackInput, AttackTrait};
    use crate::permissions::{Permissions, Role};
    use crate::world::{WorldTrait, pseudo_randomness};
    use crate::combat::CombatProgress;
    use crate::stats::UStats;
    use crate::collections::TokenAttributes;
    use crate::tags::{IdTagNew, Tag};
    use crate::erc721::erc721_owner_of;
    use crate::starknet::return_value;

    #[storage]
    struct Storage {
        pragma_dispatcher: IPragmaABIDispatcher,
        price_pairs: Map<ContractAddress, felt252>,
        token_micro_usd_price: u128,
        wallet_address: ContractAddress,
    }

    use super::{IArcade, IArcadeAdmin};
    #[generate_trait]
    impl PrivateStorageImpl of PrivateStorageTrait {
        fn get_storage(self: @ContractState) -> ArcadeStore {
            let dispatcher = self.world_dispatcher();
            ArcadeStore {
                ba: dispatcher.default_storage(), arcade: dispatcher.storage(ARCADE_NAMESPACE_HASH),
            }
        }
        fn get_arcade_storage(self: @ContractState) -> WorldStorage {
            self.storage(ARCADE_NAMESPACE_HASH)
        }
    }

    #[abi(embed_v0)]
    impl IArcadeImpl of IArcade<ContractState> {
        fn attack(ref self: ContractState, game_id: felt252, attack_id: felt252) {
            let mut store = self.get_storage();
            let game = store.arcade.get_arcade_game(game_id);
            assert(game.player == get_caller_address(), 'Not player');
            let randomness = pseudo_randomness(); //TODO: Use real randomness
            let opponent_attacks = store.arcade.get_arcade_opponent_attacks(game.opponent_token);
            store.run_arcade_round(game, attack_id, opponent_attacks, randomness);
        }
        fn start_challenge(
            ref self: ContractState,
            challenge_id: felt252,
            collection_address: ContractAddress,
            token_id: u256,
            attacks: Array<(felt252, felt252)>,
        ) -> (felt252, felt252) {
            let mut store = self.get_storage();
            let caller = get_caller_address();
            assert(erc721_owner_of(collection_address, token_id) == caller, 'Not owner');
            assert(
                store
                    .arcade
                    .get_arcade_current_challenge_attempt(caller, collection_address, token_id)
                    .is_zero(),
                'Already in challenge',
            );

            return_value(
                store
                    .new_arcade_challenge_attempt(
                        challenge_id, caller, collection_address, token_id, attacks,
                    ),
            )
        }
        fn next_challenge_round(ref self: ContractState, attempt_id: felt252) -> felt252 {
            let mut store = self.get_storage();
            return_value(store.next_arcade_challenge_round(attempt_id))
        }
        fn respawn_challenge(ref self: ContractState, attempt_id: felt252) -> felt252 {
            let mut store = self.get_storage();
            return_value(store.respawn_arcade_challenge_attempt(attempt_id))
        }
        fn end_challenge(ref self: ContractState, attempt_id: felt252) {
            let mut store = self.get_arcade_storage();
            let attempt = store.get_arcade_challenge_attempt_end_schema(attempt_id);

            assert(attempt.player == get_caller_address(), 'Not player');

            store.end_arcade_challenge_attempt(attempt_id, attempt);
        }

        fn challenge_attempt(self: @ContractState, attempt_id: felt252) -> ArcadeChallengeAttempt {
            self.get_arcade_storage().get_arcade_challenge_attempt(attempt_id)
        }

        fn game(self: @ContractState, game_id: felt252) -> ArcadeGame {
            self.get_arcade_storage().get_arcade_game(game_id)
        }

        fn challenge_attempt_game(self: @ContractState, attempt_id: felt252) -> ArcadeGame {
            self.get_arcade_storage().get_arcade_attempt_game(attempt_id)
        }

        fn game_phase(self: @ContractState, game_id: felt252) -> ArcadePhase {
            self.get_arcade_storage().get_arcade_game_phase(game_id)
        }

        fn challenge_id_from_tag(self: @ContractState, tag: ByteArray) -> felt252 {
            self.get_arcade_storage().get_tag(CHALLENGE_TAG_GROUP, @tag)
        }
        fn opponent_stats(self: @ContractState, opponent_id: felt252) -> UStats {
            self.get_arcade_storage().get_arcade_opponent_stats(opponent_id)
        }
        fn opponent_attacks(self: @ContractState, opponent_id: felt252) -> Array<felt252> {
            self.get_arcade_storage().get_arcade_opponent_attacks(opponent_id)
        }

        fn opponent_token(self: @ContractState, opponent_id: felt252) -> ArcadeOpponent {
            self.get_arcade_storage().get_arcade_opponent(opponent_id)
        }

        fn current_challenge_attempt_id(
            self: @ContractState,
            player: ContractAddress,
            collection_address: ContractAddress,
            token_id: u256,
        ) -> felt252 {
            self
                .get_arcade_storage()
                .get_arcade_current_challenge_attempt(player, collection_address, token_id)
        }

        fn callers_current_challenge_attempt_id(
            self: @ContractState, collection_address: ContractAddress, token_id: u256,
        ) -> felt252 {
            self
                .get_arcade_storage()
                .get_arcade_current_challenge_attempt(
                    get_caller_address(), collection_address, token_id,
                )
        }

        fn get_game_token_micro_usd_price(self: @ContractState, amount: u32) -> u128 {
            let price = self.token_micro_usd_price.read();
            assert(price > 0, 'Token price not set');
            amount.into() * price
        }

        fn get_game_tokens_price(
            self: @ContractState, erc20_address: ContractAddress, amount: u32,
        ) -> u256 {
            self.get_tokens_price(erc20_address, amount)
        }

        fn purchase_game_tokens(
            ref self: ContractState, erc20_address: ContractAddress, amount: u32,
        ) {
            let price = self.get_tokens_price(erc20_address, amount);
            let caller = get_caller_address();
            ERC20ABIDispatcher { contract_address: erc20_address }
                .transfer_from(caller, self.wallet_address.read(), price);
            let mut store = self.get_arcade_storage();
            store.increase_paid_games(caller, amount);
        }
    }


    #[abi(embed_v0)]
    impl IArcadeAdminImpl of IArcadeAdmin<ContractState> {
        fn new_opponent(
            ref self: ContractState,
            name: ByteArray,
            collection: ContractAddress,
            attributes: TokenAttributes,
            stats: UStats,
            attacks: Array<IdTagNew<AttackInput>>,
        ) -> felt252 {
            let mut store = self.storage(ARCADE_NAMESPACE_HASH);
            store.assert_caller_has_permission(Role::ArcadeSetter);
            let attack_ids = store.create_or_get_attacks_external(attacks);
            return_value(store.setup_new_opponent(name, collection, attributes, stats, attack_ids))
        }
        fn new_challenge(
            ref self: ContractState,
            name: ByteArray,
            health_recovery_pc: u8,
            opponents: Array<IdTagNew<ArcadeOpponentInput>>,
            collections_allowed: Array<ContractAddress>,
        ) -> felt252 {
            let mut store = self.storage(ARCADE_NAMESPACE_HASH);
            store.assert_caller_has_permission(Role::ArcadeSetter);
            return_value(
                store.setup_new_challenge(name, health_recovery_pc, opponents, collections_allowed),
            )
        }
        fn set_collection(
            ref self: ContractState, id: felt252, collection: ContractAddress, available: bool,
        ) {
            let mut store = self.storage(ARCADE_NAMESPACE_HASH);
            store.assert_caller_has_permission(Role::ArcadeSetter);
            store.set_collection_allowed(id, collection, available);
        }
        fn set_collections(
            ref self: ContractState,
            id: felt252,
            collections: Array<ContractAddress>,
            available: bool,
        ) {
            let mut store = self.storage(ARCADE_NAMESPACE_HASH);
            store.assert_caller_has_permission(Role::ArcadeSetter);
            store.set_collections_allowed(id, collections, available);
        }
        fn set_ids_collection(
            ref self: ContractState,
            ids: Array<felt252>,
            collection: ContractAddress,
            available: bool,
        ) {
            let mut store = self.storage(ARCADE_NAMESPACE_HASH);
            store.assert_caller_has_permission(Role::ArcadeSetter);
            store.set_multiple_collection_allowed(ids, collection, available);
        }
        fn mint_paid_games(ref self: ContractState, player: ContractAddress, amount: u32) {
            let mut store = self.storage(ARCADE_NAMESPACE_HASH);
            store.assert_caller_has_permission(Role::ArcadePaidMinter);
            store.increase_paid_games(player, amount);
        }

        fn set_pragma_contract_address(ref self: ContractState, contract_address: ContractAddress) {
            self.assert_caller_has_permission(Role::Manager);
            self.pragma_dispatcher.write(IPragmaABIDispatcher { contract_address });
        }

        fn set_price_pair(
            ref self: ContractState, erc20_address: ContractAddress, price_pair: felt252,
        ) {
            self.assert_caller_has_permission(Role::Manager);
            self.price_pairs.write(erc20_address, price_pair);
        }

        fn set_token_micro_usd_price(ref self: ContractState, price: u128) {
            self.assert_caller_has_permission(Role::Manager);
            self.token_micro_usd_price.write(price);
        }

        fn set_wallet_address(ref self: ContractState, wallet_address: ContractAddress) {
            self.assert_caller_has_permission(Role::Manager);
            self.wallet_address.write(wallet_address);
        }
    }


    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn get_tokens_price(
            self: @ContractState, erc20_address: ContractAddress, amount: u32,
        ) -> u256 {
            let price_pair = self.price_pairs.read(erc20_address);
            assert(price_pair.is_non_zero(), 'ERC20 not accepted');
            let PragmaPricesResponse {
                price,
                decimals,
                last_updated_timestamp: _,
                num_sources_aggregated: _,
                expiration_timestamp: _,
            } = self.pragma_dispatcher.read().get_data_median(DataType::SpotEntry(price_pair));

            (self.token_micro_usd_price.read().into()
                * amount.into()
                * 10_u256.pow(decimals.into())
                * 1_000_000_000_000_000_000
                / (price.into() * 1_000_000))
                .into()
        }
    }
}
