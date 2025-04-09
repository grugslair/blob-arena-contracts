use starknet::ContractAddress;
use crate::permissions::Role;

#[starknet::interface]
trait IGame<TContractState> {
    /// Starts a new game already created with a given game ID
    /// # Arguments
    /// * `game_id` - The unique identifier for the game to start
    ///
    /// Models:
    /// - CombatState
    fn start(ref self: TContractState, game_id: felt252);

    /// Commits a player's move by storing a hash of their attack and salt
    /// # Arguments
    /// * `combatant_id` - The unique identifier of the combatant making the move
    /// * `hash` - The hashed combination of the player's attack and salt
    ///
    /// Models:
    /// - CommitmentModel
    /// - CombatState
    /// - LastTimestamp
    fn commit(ref self: TContractState, combatant_id: felt252, hash: felt252);

    /// Reveals a player's previously committed move
    /// # Arguments
    /// * `combatant_id` - The unique identifier of the combatant revealing their move
    /// * `attack` - The actual attack value that was committed
    /// * `salt` - The salt value used in the original commitment
    ///
    /// Models:
    /// - CommitmentModel
    /// - PlannedAttack
    /// - LastTimestamp
    /// - CombatState
    ///
    /// Events:
    /// - CombatEnd
    fn reveal(ref self: TContractState, combatant_id: felt252, attack: felt252, salt: felt252);

    /// Executes a combat round for a specific combat
    /// # Arguments
    /// * `combat_id` - The unique identifier of the combat to run
    ///
    /// Models:
    /// - CombatantState
    /// - AttackLastUsed
    /// - CombatState
    ///
    /// Events:
    /// - RoundResult
    /// - CombatEnd
    fn run(ref self: TContractState, combat_id: felt252);

    /// Removes an inactive player from the game
    /// # Arguments
    /// * `combat_id` - The unique identifier of the combat containing the player to kick
    ///
    /// Models:
    /// - CombatState
    ///
    /// Events:
    /// - CombatEnd
    fn kick_player(ref self: TContractState, combat_id: felt252);

    /// Allows a player to forfeit their position in the game
    /// # Arguments
    /// * `combatant_id` - The unique identifier of the combatant forfeiting
    ///
    /// Models:
    /// - CombatState
    ///
    /// Events:
    /// - CombatEnd
    fn forfeit(ref self: TContractState, combatant_id: felt252);

    /// Returns the address of the winning player for a specific combat
    /// # Arguments
    /// * `combat_id` - The unique identifier of the combat to check
    /// # Returns
    /// * `ContractAddress` - The address of the winning player
    fn get_winning_player(self: @TContractState, combat_id: felt252) -> ContractAddress;
}

#[starknet::interface]
trait IGameAdmin<TContractState> {
    /// Creates a new game instance with specified parameters
    ///
    /// * `owner` - The owner of the game instance
    /// * `initiator` - The address that initiates the game
    /// * `time_limit` - Time limit for the game in seconds
    /// * `player_a` - Address of the first player
    /// * `collection_address_a` - NFT collection address for player A's blob
    /// * `token_id_a` - Token ID of player A's blob
    /// * `attacks_a` - Array of attack moves for player A as (felt252, felt252) tuples
    /// * `player_b` - Address of the second player
    /// * `collection_address_b` - NFT collection address for player B's blob
    /// * `token_id_b` - Token ID of player B's blob
    /// * `attacks_b` - Array of attack moves for player B as (felt252, felt252) tuples
    ///
    /// * Returns: A felt252 representing the game ID
    ///
    /// Models:
    /// - CombatantInfo
    /// - CombatantToken
    /// - CombatantState
    /// - AttackAvailable
    /// - GameInfo
    /// - Initiator
    /// - CombatState
    ///
    fn create(
        ref self: TContractState,
        owner: ContractAddress,
        initiator: ContractAddress,
        time_limit: u64,
        player_a: ContractAddress,
        collection_address_a: ContractAddress,
        token_id_a: u256,
        attacks_a: Array<(felt252, felt252)>,
        player_b: ContractAddress,
        collection_address_b: ContractAddress,
        token_id_b: u256,
        attacks_b: Array<(felt252, felt252)>,
    ) -> felt252;
}


#[dojo::contract]
mod game_actions {
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_timestamp};
    use dojo::{world::{WorldStorage, WorldStorageTrait}};
    use crate::attacks::AttackStorage;
    use crate::combat::{Phase, CombatTrait, CombatState, CombatStorage};
    use crate::combatants::{CombatantTrait, CombatantStorage, CombatantInfo};
    use crate::game::{components::{GameInfoTrait, WinVia}, GameStorage, systems::GameTrait};
    use crate::world::{WorldTrait, uuid};
    use crate::commitments::Commitment;
    use crate::core::{TTupleSized2ToSpan, ArrayTryIntoTTupleSized2};
    use crate::permissions::Permissions;

    use super::{IGame, IGameAdmin};


    #[abi(embed_v0)]
    impl IGameImpl of IGame<ContractState> {
        fn start(ref self: ContractState, game_id: felt252) {
            let mut world = self.default_storage();
            world.assert_caller_initiator(game_id);
            world.assert_created_phase(game_id);
            world.assert_contract_is_owner(game_id);
            world.set_combat_phase(game_id, Phase::Commit);
        }
        fn commit(ref self: ContractState, combatant_id: felt252, hash: felt252) {
            let mut world = self.default_storage();
            let combatant = world.get_callers_combatant_info(combatant_id);
            let game = world.get_owners_game(combatant.combat_id, get_contract_address());
            let opponent_id = game.get_opponent_id(combatant_id);
            world.assert_commit_phase(game.combat_id);
            world.set_new_commitment(combatant_id, hash);

            if world.check_commitment_set(opponent_id) {
                world.set_combat_phase(game.combat_id, Phase::Reveal);
            } else if game.time_limit.is_non_zero() {
                world.set_last_timestamp_now(game.combat_id);
            }
        }
        fn reveal(ref self: ContractState, combatant_id: felt252, attack: felt252, salt: felt252) {
            let mut world = self.default_storage();
            let combatant = world.get_callers_combatant_info(combatant_id);
            let game = world.get_owners_game(combatant.combat_id, get_contract_address());

            let opponent_id = game.get_opponent_id(combatant_id);
            let timestamp = get_block_timestamp();
            if world.consume_and_compare_commitment_value(combatant_id, @(attack, salt)) {
                world.set_planned_attack(combatant_id, attack, opponent_id, salt);
                if world.check_commitment_set(opponent_id) {
                    world.set_last_timestamp(game.combat_id, timestamp);
                }
            } else {
                world
                    .end_game_from_ids(
                        game.combat_id,
                        opponent_id,
                        combatant_id,
                        timestamp,
                        WinVia::IncorrectReveal,
                    );
            }
        }
        fn run(ref self: ContractState, combat_id: felt252) {
            let mut world = self.default_storage();

            world.run_game_round(world.get_owners_game(combat_id, get_contract_address()));
        }

        fn kick_player(ref self: ContractState, combat_id: felt252) {
            let mut storage = self.default_storage();
            let game = storage.get_owners_game(combat_id, get_contract_address());
            let (a, b) = game.combatant_ids;
            storage.assert_past_time_limit(game);

            let xor = match storage.get_combat_phase(game.combat_id) {
                Phase::Commit => true,
                Phase::Reveal => false,
                _ => { panic!("Game not running") },
            };

            let are_set: (bool, bool) = storage
                .check_commitments_are(game.combatant_ids.span(), xor)
                .try_into()
                .unwrap();
            let (winner_id, looser_id) = match are_set {
                (true, false) => (a, b),
                (false, true) => (b, a),
                (true, true) => panic!("Both players have played"),
                (false, false) => panic!("Neither players have played"),
            };

            storage
                .end_game_from_ids(
                    game.combat_id, winner_id, looser_id, get_block_timestamp(), WinVia::TimeLimit,
                );
        }

        fn forfeit(ref self: ContractState, combatant_id: felt252) {
            let mut world = self.default_storage();
            let combatant = world.get_callers_combatant_info(combatant_id);
            let game = world.get_owners_game(combatant.combat_id, get_contract_address());

            world.assert_combat_running(game.combat_id);

            let opponent = world.get_opponent(game, combatant_id);

            world
                .end_game(
                    game.combat_id, opponent, combatant, get_block_timestamp(), WinVia::Forfeit,
                );
        }

        fn get_winning_player(self: @ContractState, combat_id: felt252) -> ContractAddress {
            let storage = self.default_storage();
            storage.get_winning_player(combat_id)
        }
    }


    #[abi(embed_v0)]
    impl IGameAdminImpl of IGameAdmin<ContractState> {
        fn create(
            ref self: ContractState,
            owner: ContractAddress,
            initiator: ContractAddress,
            time_limit: u64,
            player_a: ContractAddress,
            collection_address_a: ContractAddress,
            token_id_a: u256,
            attacks_a: Array<(felt252, felt252)>,
            player_b: ContractAddress,
            collection_address_b: ContractAddress,
            token_id_b: u256,
            attacks_b: Array<(felt252, felt252)>,
        ) -> felt252 {
            let mut world = self.default_storage();
            world.assert_caller_is_admin();

            let id = uuid();
            let player_a_id = uuid();
            let player_b_id = uuid();

            world
                .create_player_combatant(
                    player_a_id, player_a, id, collection_address_a, token_id_a, attacks_a,
                );
            world
                .create_player_combatant(
                    player_b_id, player_b, id, collection_address_b, token_id_b, attacks_b,
                );

            world.set_game_info(id, owner, time_limit, player_a_id, player_b_id);
            world.set_initiator(id, initiator);
            world.new_combat_state(id);
            id
        }
    }
}
