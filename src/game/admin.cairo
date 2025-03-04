use starknet::ContractAddress;
use blob_arena::permissions::Role;

/// Interface for administrating the game.
///
/// # Interface Functions
///
/// * `create` - Creates a new game instance with specified parameters
///   * `owner` - The owner of the game instance
///   * `initiator` - The address that initiates the game creation (tournament or betting contract)
///   * `time_limit` - Time limit for player inactivity in the game
///   * `player_a` - Address of first player
///   * `collection_address_a` - NFT collection address for first player
///   * `token_id_a` - Token ID of first player's NFT
///   * `attacks_a` - Array of attack tuples for first player
///   * `player_b` - Address of second player
///   * `collection_address_b` - NFT collection address for second player
///   * `token_id_b` - Token ID of second player's NFT
///   * `attacks_b` - Array of attack tuples for second player
///   * Returns the game ID as felt252
///
/// * `set_is_admin` - Sets admin status for a user
///   * `user` - Address to set admin status for
///   * `has` - Boolean indicating if user should have admin status
///
/// * `set_is_creator` - Sets creator status for a user
///   * `user` - Address to set creator status for
///   * `has` - Boolean indicating if user should have creator status
///
/// * `get_is_admin` - Checks if a user has admin status
///   * `user` - Address to check
///   * Returns boolean indicating admin status
///
/// * `get_is_creator` - Checks if a user has creator status
///   * `user` - Address to check
///   * Returns boolean indicating creator status
///
/// * `get_world_address` - Gets the address of the world contract
///   * Returns the ContractAddress of the world contract
#[starknet::interface]
trait IGameAdmin<TContractState> {
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
    fn set_has_role(ref self: TContractState, user: ContractAddress, role: Role, has: bool);
    fn get_has_role(self: @TContractState, user: ContractAddress, role: Role) -> bool;
    fn set_multiple_has_role(
        ref self: TContractState, users: Array<ContractAddress>, role: Role, has: bool,
    );
    fn get_world_address(self: @TContractState) -> ContractAddress;
}

#[dojo::contract]
mod game_admin {
    use dojo::world::WorldStorage;
    use starknet::{ContractAddress, get_tx_info, get_caller_address};
    use blob_arena::{
        world::{DEFAULT_NAMESPACE_HASH, uuid, get_world_address}, game::GameStorage,
        combatants::CombatantTrait, combat::CombatStorage,
        permissions::{Role, Permissions, Permission, PermissionStorage},
    };

    use super::IGameAdmin;

    fn dojo_init(ref self: ContractState) {
        let mut world = self.get_storage();

        let admin = get_tx_info().unbox().account_contract_address;
        world.set_permission(admin, Role::Admin, true);
    }

    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn get_storage(self: @ContractState) -> WorldStorage {
            self.world_ns_hash(DEFAULT_NAMESPACE_HASH)
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
            let mut world = self.get_storage();
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

        fn set_has_role(ref self: ContractState, user: ContractAddress, role: Role, has: bool) {
            let mut world = self.get_storage();
            world.assert_caller_is_admin();
            world.set_permission(user, role, has);
        }

        fn get_has_role(self: @ContractState, user: ContractAddress, role: Role) -> bool {
            let world = self.get_storage();
            world.get_permission(user, role)
        }

        fn set_multiple_has_role(
            ref self: ContractState, users: Array<ContractAddress>, role: Role, has: bool,
        ) {
            let mut world = self.get_storage();
            world.assert_caller_is_admin();
            let mut permissions = ArrayTrait::<Permission>::new();
            for user in users {
                permissions.append(Permission { requester: user, role, has });
            };
            world.set_permissions(permissions);
        }

        fn get_world_address(self: @ContractState) -> ContractAddress {
            get_world_address()
        }
    }
}
