use starknet::ContractAddress;
use blob_arena::permissions::Role;


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
mod game_admin_actions {
    use dojo::world::WorldStorage;
    use starknet::ContractAddress;
    use blob_arena::{
        world::{WorldTrait, uuid}, game::GameStorage, combatants::CombatantTrait,
        combat::CombatStorage, permissions::Permissions,
    };

    use super::IGameAdmin;

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
