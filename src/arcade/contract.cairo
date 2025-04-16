use starknet::ContractAddress;
use crate::stats::UStats;
use crate::arcade::ArcadeOpponentInput;
use crate::collections::{TokenAttributes, BlobertItemKey};
use crate::tags::IdTagNew;
use crate::attacks::components::AttackInput;

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

    /// Claims a free game attempt.
    ///
    /// Models:
    /// - ArcadeFreeGames
    fn claim_free_game(ref self: TContractState);
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

    /// Mints free game passes for a player
    /// # Arguments
    /// * `player` - Address of player receiving games
    /// * `amount` - Number of free games to mint
    ///
    /// Models
    /// - ArcadeFreeGames
    fn mint_free_games(ref self: TContractState, player: ContractAddress, amount: u32);

    /// Mints paid game passes for a player
    /// # Arguments
    /// * `player` - Address of player receiving games
    /// * `amount` - Number of paid games to mint
    ///
    /// Models:
    /// - ArcadePaidGames
    fn mint_paid_games(ref self: TContractState, player: ContractAddress, amount: u32);
}


#[dojo::contract]
mod arcade_actions {
    use starknet::{ContractAddress, get_caller_address};
    use dojo::world::WorldStorage;
    use crate::arcade::{
        ArcadeTrait, ArcadeStorage, ARCADE_NAMESPACE_HASH, ArcadeStore, ArcadeOpponentInput,
    };
    use crate::attacks::{AttackInput, AttackTrait};
    use crate::permissions::{Permissions, Role};
    use crate::world::WorldTrait;
    use crate::combat::CombatProgress;
    use crate::stats::UStats;
    use crate::collections::TokenAttributes;
    use crate::tags::IdTagNew;
    use crate::utils::get_transaction_hash;
    use crate::erc721::erc721_owner_of;
    use crate::starknet::return_value;

    use super::{IArcade, IArcadeAdmin};
    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
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
            let randomness = get_transaction_hash(); //TODO: Use real randomness
            store.run_arcade_round(game, attack_id, randomness);
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
            store.arcade.use_game(caller);

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

        fn claim_free_game(ref self: ContractState) {
            let mut store = self.get_arcade_storage();
            store.mint_free_game(get_caller_address());
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
        fn mint_free_games(ref self: ContractState, player: ContractAddress, amount: u32) {
            let mut store = self.storage(ARCADE_NAMESPACE_HASH);
            store.assert_caller_has_permission(Role::ArcadeFreeMinter);
            let mut model = store.get_free_games(player);
            model.games += amount;
            if model.last_claim.is_non_zero() {
                store.set_number_of_free_games(player, model.games);
            } else {
                store.set_free_games_model(model)
            }
        }
        fn mint_paid_games(ref self: ContractState, player: ContractAddress, amount: u32) {
            let mut store = self.storage(ARCADE_NAMESPACE_HASH);
            store.assert_caller_has_permission(Role::ArcadePaidMinter);
            let games = store.get_number_of_paid_games(player);
            store.set_number_of_paid_games(player, games + amount);
        }
    }
}
