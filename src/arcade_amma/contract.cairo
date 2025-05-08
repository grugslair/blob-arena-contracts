use starknet::ContractAddress;
use crate::stats::UStats;
use crate::tags::IdTagNew;
use crate::collections::{TokenAttributes, BlobertItemKey};
use crate::attacks::components::AttackInput;
use crate::arcade::{
    ArcadeGame, ArcadeChallengeAttempt, ArcadePhase, ArcadeOpponent, ArcadeOpponentInput,
};

#[starknet::interface]
trait IAmmaArcade<TContractState> {
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
        ref self: TContractState, token_id: u256, attacks: Array<(felt252, felt252)>,
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

    /// Generates a boss for the current challenge attempt.
    /// # Arguments
    /// * `attempt_id` - The unique identifier of the challenge attempt
    ///
    /// Models:
    /// - AmmaArcadeOpponent
    fn generate_boss(ref self: TContractState, attempt_id: felt252);

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
}

/// Interface for managing Arcade (Player vs Environment) administrative functions.
#[starknet::interface]
trait IAmmaArcadeAdmin<TContractState> {
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
}


#[dojo::contract]
mod arcade_amma_actions {
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use dojo::world::WorldStorage;
    use crate::arcade::{
        ArcadeTrait, ArcadeStorage, ArcadeStore, ArcadeOpponentInput, ArcadeChallengeAttempt,
        ArcadeGame, ArcadePhase, CHALLENGE_TAG_GROUP, ArcadeOpponent,
    };
    use crate::arcade_amma::{
        AmmaArcadeStorage, AmmaArcadeTrait, AMMA_ARCADE_NAMESPACE_HASH,
        AMMA_ARCADE_GENERATED_STAGES,
    };
    use crate::attacks::{AttackInput, AttackTrait};
    use crate::permissions::{Permissions, Role};
    use crate::world::WorldTrait;
    use crate::combat::CombatProgress;
    use crate::stats::UStats;
    use crate::collections::TokenAttributes;
    use crate::tags::{IdTagNew, Tag};
    use crate::utils::{get_transaction_hash, SeedProbability};
    use crate::erc721::erc721_owner_of;
    use crate::starknet::return_value;
    use crate::hash::felt252_to_u128;


    #[storage]
    struct Storage {
        collection_address: ContractAddress,
        fighters: u32,
    }

    use super::{IAmmaArcade, IAmmaArcadeAdmin};
    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn get_storage(self: @ContractState) -> ArcadeStore {
            let dispatcher = self.world_dispatcher();
            ArcadeStore {
                ba: dispatcher.default_storage(),
                arcade: dispatcher.storage(AMMA_ARCADE_NAMESPACE_HASH),
            }
        }
        fn get_arcade_storage(self: @ContractState) -> WorldStorage {
            self.storage(AMMA_ARCADE_NAMESPACE_HASH)
        }
    }

    #[abi(embed_v0)]
    impl IAmmaArcadeImpl of IAmmaArcade<ContractState> {
        fn attack(ref self: ContractState, game_id: felt252, attack_id: felt252) {
            let mut store = self.get_storage();
            let game = store.arcade.get_arcade_game(game_id);
            assert(game.player == get_caller_address(), 'Not player');
            let randomness = get_transaction_hash(); //TODO: Use real randomness
            store.run_arcade_round(game, attack_id, randomness);
        }
        fn start_challenge(
            ref self: ContractState, token_id: u256, attacks: Array<(felt252, felt252)>,
        ) -> (felt252, felt252) {
            let mut store = self.get_storage();
            let caller = get_caller_address();
            let collection_address = self.collection_address.read();
            let randomness = get_transaction_hash();
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
                    .new_amma_arcade_challenge_attempt(
                        randomness,
                        caller,
                        collection_address,
                        token_id,
                        attacks,
                        self.fighters.read(),
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
        fn generate_boss(ref self: ContractState, attempt_id: felt252) {
            let mut store = self.get_arcade_storage();
            let player_stage = store.get_amma_arcade_challenge_attempt_player_stage(attempt_id);
            assert(store.get_amma_round_opponent(attempt_id, 10).is_zero(), 'Already generated');
            assert(get_caller_address() == player_stage.player, 'Not player');
            assert(player_stage.stage == AMMA_ARCADE_GENERATED_STAGES, 'Not last stage');
            let mut randomness = felt252_to_u128(get_transaction_hash());
            let fighters: u128 = self.fighters.read().into();
            let fighter = 1 + randomness.get_value(fighters.try_into().unwrap());
            store.set_amma_round_opponent(attempt_id, 10, fighter.try_into().unwrap());
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
        fn opponent_stats(self: @ContractState, opponent_id: felt252) -> UStats {
            self.get_arcade_storage().get_arcade_opponent_stats(opponent_id)
        }
        fn opponent_attacks(self: @ContractState, opponent_id: felt252) -> Array<felt252> {
            self.get_arcade_storage().get_arcade_opponent_attacks(opponent_id)
        }

        fn opponent_token(self: @ContractState, opponent_id: felt252) -> ArcadeOpponent {
            self.get_arcade_storage().get_arcade_opponent(opponent_id)
        }
    }


    #[abi(embed_v0)]
    impl IAmmaArcadeAdminImpl of IAmmaArcadeAdmin<ContractState> {
        fn new_opponent(
            ref self: ContractState,
            name: ByteArray,
            collection: ContractAddress,
            attributes: TokenAttributes,
            stats: UStats,
            attacks: Array<IdTagNew<AttackInput>>,
        ) -> felt252 {
            let mut store = self.get_arcade_storage();
            store.assert_caller_has_permission(Role::ArcadeSetter);
            let attack_ids = store.create_or_get_attacks_external(attacks);
            return_value(store.setup_new_opponent(name, collection, attributes, stats, attack_ids))
        }
        fn set_collection(
            ref self: ContractState, id: felt252, collection: ContractAddress, available: bool,
        ) {
            let mut store = self.get_arcade_storage();
            store.assert_caller_has_permission(Role::ArcadeSetter);
            store.set_collection_allowed(id, collection, available);
        }
        fn set_collections(
            ref self: ContractState,
            id: felt252,
            collections: Array<ContractAddress>,
            available: bool,
        ) {
            let mut store = self.get_arcade_storage();
            store.assert_caller_has_permission(Role::ArcadeSetter);
            store.set_collections_allowed(id, collections, available);
        }
        fn set_ids_collection(
            ref self: ContractState,
            ids: Array<felt252>,
            collection: ContractAddress,
            available: bool,
        ) {
            let mut store = self.get_arcade_storage();
            store.assert_caller_has_permission(Role::ArcadeSetter);
            store.set_multiple_collection_allowed(ids, collection, available);
        }
        fn mint_paid_games(ref self: ContractState, player: ContractAddress, amount: u32) {
            let mut store = self.get_arcade_storage();
            store.assert_caller_has_permission(Role::ArcadePaidMinter);
            let games = store.get_number_of_paid_games(player);
            store.set_number_of_paid_games(player, games + amount);
        }
    }
}
