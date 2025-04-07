use starknet::ContractAddress;
use blob_arena::{stats::UStats, collections::blobert::{TokenAttributes, BlobertItemKey}};


/// Interface for the Arcade (Player vs Environment) game contract
///
/// # Functions
///
/// * `start_game` - Initiates a new Arcade game session
///   * `opponent_id` - Identifier for the opponent to fight
///   * `collection_address` - Contract address of the NFT collection
///   * `token_id` - ID of the token being used
///   * `attacks` - Array of attack tuples (item_n, slot_n) where item_n is 1, 2, 3... for
///   Background, Armour, Jewelry....
///   * Returns: game_id as felt252
///
/// * `attack` - Executes an attack in an ongoing game
///   * `game_id` - Identifier of the active game
///   * `attack_id` - The id of the attack to perform
///
/// * `start_challenge` - Begins a new challenge mode session
///   * `challenge_id` - Identifier for the specific challenge
///   * `collection_address` - Contract address of the NFT collection
///   * `token_id` - ID of the token being used
///   * `attacks` - Array of attack tuples (item_n, slot_n) where item_n is 1, 2, 3... for
///   Background, Armour, Jewelry....
///
/// * `next_challenge_round` - Advances to the next round in a challenge
///   * `attempt_id` - Identifier for the current challenge attempt
///
/// * `respawn_challenge` - Restarts a challenge attempt
///   * `attempt_id` - Identifier for the challenge attempt to respawn
///
/// * `end_challenge` - Concludes an active challenge
///   * `attempt_id` - Identifier for the challenge attempt to end
///
/// * `claim_free_game` - Claims a free game session for the player
///

#[starknet::interface]
trait IArcade<TContractState> {
    /// Starts a new Arcade game against an opponent.
    /// # Arguments
    /// * `opponent_id` - The unique identifier of the opponent to fight against
    /// * `collection_address` - The contract address of the NFT collection
    /// * `token_id` - The token ID of the NFT being used
    /// * `attacks` - Array of attack tuples (attack_id, attack_power)
    /// # Returns
    /// * `felt252` - The game ID of the newly created game
    ///
    /// Models:
    /// - ArcadeFreeGames
    /// - ArcadePaidGames
    /// - AttackAvailable
    /// - CombatantToken
    /// - CombatantState
    /// - ArcadeGame
    fn start_game(
        ref self: TContractState,
        opponent_id: felt252,
        collection_address: ContractAddress,
        token_id: u256,
        attacks: Array<(felt252, felt252)>,
    ) -> felt252;

    /// Executes an attack move in an active game.
    /// # Arguments
    /// * `game_id` - The unique identifier of the active game
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
    );

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
    fn next_challenge_round(ref self: TContractState, attempt_id: felt252);

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
    fn respawn_challenge(ref self: TContractState, attempt_id: felt252);

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


#[dojo::contract]
mod arcade_actions {
    use starknet::{ContractAddress, get_caller_address};
    use dojo::world::WorldStorage;
    use blob_arena::{
        arcade::{ArcadeTrait, ArcadeStorage, ARCADE_NAMESPACE_HASH, ArcadeStore}, world::WorldTrait,
        game::GameProgress, utils::get_transaction_hash, stats::UStats,
        collections::blobert::{TokenAttributes, BlobertItemKey, BlobertStorage},
        erc721::erc721_owner_of,
    };
    use super::{IArcade};
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
        fn start_game(
            ref self: ContractState,
            opponent_id: felt252,
            collection_address: ContractAddress,
            token_id: u256,
            attacks: Array<(felt252, felt252)>,
        ) -> felt252 {
            let mut store = self.get_storage();
            let caller = get_caller_address();
            assert(erc721_owner_of(collection_address, token_id) == caller, 'Not owner');
            store.arcade.use_game(caller);
            store.new_arcade_game(opponent_id, caller, collection_address, token_id, attacks)
        }
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
        ) {
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

            store
                .new_arcade_challenge_attempt(
                    challenge_id, caller, collection_address, token_id, attacks,
                );
        }
        fn next_challenge_round(ref self: ContractState, attempt_id: felt252) {
            let mut store = self.get_storage();
            store.next_arcade_challenge_round(attempt_id);
        }
        fn respawn_challenge(ref self: ContractState, attempt_id: felt252) {
            let mut store = self.get_storage();
            store.respawn_arcade_challenge_attempt(attempt_id);
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
}
