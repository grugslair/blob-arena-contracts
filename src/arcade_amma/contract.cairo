use starknet::ContractAddress;
use crate::stats::UStats;
use crate::tags::IdTagNew;
use crate::collections::{TokenAttributes, BlobertItemKey};
use crate::attacks::components::AttackInput;
use crate::arcade::{ArcadeGame, ArcadePhase, ArcadeOpponent, ArcadeOpponentInput};
use crate::arcade_amma::AmmaArcadeChallengeAttempt;

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
    /// - AmmaArcadeChallengeAttempt
    /// - ArcadeStageGame
    /// - AmmaArcadeStageOpponent
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
    /// - AmmaArcadeChallengeAttempt
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
    /// - AmmaArcadeChallengeAttempt
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
    /// - AmmaArcadeChallengeAttempt
    /// - ArcadeGame
    fn end_challenge(ref self: TContractState, attempt_id: felt252);

    /// Generates a boss for the current challenge attempt.
    /// # Arguments
    /// * `attempt_id` - The unique identifier of the challenge attempt
    ///
    /// Models:
    /// - AmmaArcadeStageOpponent
    fn generate_boss(ref self: TContractState, attempt_id: felt252);

    /// Gets the challenge attemt
    ///
    /// # Arguments
    /// * `attempt_id` - The unique identifier of the challenge attempt
    ///
    /// Returns:
    /// - `ArcadeChallengeAttempt` - The challenge attempt object
    fn challenge_attempt(self: @TContractState, attempt_id: felt252) -> AmmaArcadeChallengeAttempt;

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
    /// Sets availability of a single collection for a specific ID
    /// # Arguments
    /// * `collection` - Collection address to set
    ///
    /// Models:
    /// - ArcadeCollectionAllowed
    ///
    fn set_collection_address(ref self: TContractState, collection_address: ContractAddress);
}


#[dojo::contract]
mod arcade_amma_actions {
    use core::poseidon::poseidon_hash_span;
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use dojo::world::WorldStorage;
    use crate::collections::amma_blobert::{AmmaBlobertStorage, get_amount_of_fighters};
    use crate::arcade::{
        ArcadeTrait, ArcadeStorage, ArcadeStore, ArcadeOpponentInput, ArcadeChallengeAttempt,
        ArcadeGame, ArcadePhase, CHALLENGE_TAG_GROUP, ArcadeOpponent,
    };
    use crate::arcade_amma::{
        AmmaArcadeStorage, AmmaArcadeTrait, AMMA_ARCADE_NAMESPACE_HASH,
        AMMA_ARCADE_GENERATED_STAGES, AmmaArcadeChallengeAttempt,
    };
    use crate::attacks::{AttackInput, AttackTrait};
    use crate::permissions::{Permissions, Role};
    use crate::world::{WorldTrait, pseudo_randomness};
    use crate::combat::CombatProgress;
    use crate::stats::UStats;
    use crate::collections::TokenAttributes;
    use crate::tags::{IdTagNew, Tag};
    use crate::utils::SeedProbability;
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
            let randomness = pseudo_randomness(); //TODO: Use real randomness
            let opponent_attacks = store.arcade.get_amma_fighter_attacks(game.opponent_token);

            store.run_arcade_round(game, attack_id, opponent_attacks, randomness);
        }
        fn start_challenge(
            ref self: ContractState, token_id: u256, attacks: Array<(felt252, felt252)>,
        ) -> (felt252, felt252) {
            let mut store = self.get_storage();
            let caller = get_caller_address();
            let collection_address = self.collection_address.read();
            let randomness = pseudo_randomness();
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
                        randomness, caller, collection_address, token_id, attacks,
                    ),
            )
        }
        fn next_challenge_round(ref self: ContractState, attempt_id: felt252) -> felt252 {
            let mut store = self.get_storage();
            return_value(store.next_amma_arcade_challenge_round(attempt_id))
        }
        fn respawn_challenge(ref self: ContractState, attempt_id: felt252) -> felt252 {
            let mut store = self.get_storage();
            return_value(store.respawn_amma_arcade_challenge_attempt(attempt_id))
        }
        fn end_challenge(ref self: ContractState, attempt_id: felt252) {
            let mut store = self.get_arcade_storage();

            store.end_amma_arcade_challenge_attempt(self.collection_address.read(), attempt_id);
        }
        fn generate_boss(ref self: ContractState, attempt_id: felt252) {
            let mut store = self.get_arcade_storage();
            let player_stage = store.get_amma_arcade_challenge_attempt_player_stage(attempt_id);
            assert(
                store.get_amma_round_opponent(attempt_id, AMMA_ARCADE_GENERATED_STAGES).is_zero(),
                'Already generated',
            );
            let fighters: u128 = get_amount_of_fighters(self.collection_address.read()).into();
            assert(get_caller_address() == player_stage.player, 'Not player');
            assert(player_stage.stage == AMMA_ARCADE_GENERATED_STAGES - 1, 'Not last stage');
            let mut randomness = felt252_to_u128(pseudo_randomness());
            let fighter = randomness.get_value(fighters.try_into().unwrap());
            store.set_amma_round_opponent(attempt_id, 9, fighter.try_into().unwrap());
        }

        fn challenge_attempt(
            self: @ContractState, attempt_id: felt252,
        ) -> AmmaArcadeChallengeAttempt {
            self.get_arcade_storage().get_amma_arcade_challenge_attempt(attempt_id)
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
        fn set_collection_address(ref self: ContractState, collection_address: ContractAddress) {
            self.assert_caller_has_permission(Role::ArcadeSetter);
            self.collection_address.write(collection_address);
        }
    }
}
