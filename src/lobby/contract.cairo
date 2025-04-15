use starknet::ContractAddress;

#[starknet::interface]
trait ILobby<TContractState> {
    /// ## send_invite
    /// Creates a new lobby invite for a PvP match
    /// * `initiator` - The address that initiates the match
    /// * `time_limit` - Time limit for player inactivity in seconds
    /// * `receiver` - Address of the invited receiver
    /// * `collection_address` - NFT collection address for the blobert
    /// * `token_id` - Token ID to use
    /// * `attacks` - Array of attack moves as (felt252, felt252) tuples
    /// * Returns: A felt252 representing the lobby ID
    ///
    /// Models:
    /// - Lobby
    /// - GameInfo
    /// - Initiator
    /// - CombatantInfo
    /// - CombatantToken
    /// - CombatantState
    /// - AttackAvailable
    ///
    /// Events:
    /// - LobbyCreated
    fn send_invite(
        ref self: TContractState,
        initiator: ContractAddress,
        time_limit: u64,
        receiver: ContractAddress,
        collection_address: ContractAddress,
        token_id: u256,
        attacks: Array<(felt252, felt252)>,
    ) -> felt252;

    /// ## rescind_invite
    /// Cancels an existing lobby invite
    /// * `challenge_id` - ID of the lobby to cancel
    ///
    /// Models:
    /// - Lobby
    fn rescind_invite(ref self: TContractState, challenge_id: felt252);

    /// ## respond_invite
    /// Accepts a lobby invite with specified blob and attacks
    /// * `challenge_id` - ID of the lobby to respond to
    /// * `token_id` - Token ID of the responding player's blob
    /// * `attacks` - Array of attack moves as (felt252, felt252) tuples
    ///
    /// Models:
    /// - CombatantInfo
    /// - GameInfo
    /// - CombatantInfo
    /// - CombatantToken
    /// - CombatantState
    /// - AttackAvailable
    fn respond_invite(
        ref self: TContractState,
        challenge_id: felt252,
        token_id: u256,
        attacks: Array<(felt252, felt252)>,
    );
    /// ## reject_invite
    /// Rejects an incoming lobby invite
    /// * `challenge_id` - ID of the lobby to reject#
    ///
    /// Models:
    /// - Lobby
    fn reject_invite(ref self: TContractState, challenge_id: felt252);
    /// ## rescind_response
    /// Withdraws a previous response to an invite
    /// * `challenge_id` - ID of the lobby to withdraw from
    ///
    /// Models:
    /// - GameInfo
    fn rescind_response(ref self: TContractState, challenge_id: felt252);
    /// ## accept_response
    /// Finalizes the lobby and starts the match
    /// * `challenge_id` - ID of the lobby to finalize
    ///
    /// Models:
    /// - CombatState
    fn accept_response(ref self: TContractState, challenge_id: felt252);
    /// ## reject_response
    /// Rejects a player's response to an invite
    /// * `challenge_id` - ID of the lobby response to reject
    ///
    /// Models:
    /// - GameInfo
    fn reject_response(ref self: TContractState, challenge_id: felt252);
}


#[dojo::contract]
mod lobby_actions {
    const SELECTOR: felt252 = selector!("blob_arena-pvp_actions");
    use starknet::{ContractAddress, get_caller_address};
    use dojo::world::WorldStorage;

    use crate::lobby::{systems::LobbyTrait, storage::LobbyStorage};
    use crate::combat::{CombatTrait, CombatStorage};
    use crate::game::GameStorage;
    use crate::combatants::{CombatantTrait, CombatantStorage};
    use crate::utils::get_transaction_hash;
    use crate::world::{uuid, default_namespace};
    use crate::starknet::return_value;
    use crate::erc721::erc721_owner_of;
    use crate::permissions::{Role, Permissions};

    use super::ILobby;

    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn get_storage(self: @ContractState) -> WorldStorage {
            self.world(default_namespace())
        }
    }

    #[abi(embed_v0)]
    impl ILobbyImpl of ILobby<ContractState> {
        fn send_invite(
            ref self: ContractState,
            initiator: ContractAddress,
            time_limit: u64,
            receiver: ContractAddress,
            collection_address: ContractAddress,
            token_id: u256,
            attacks: Array<(felt252, felt252)>,
        ) -> felt252 {
            let mut world = self.get_storage();

            let id = uuid();
            let sender_id = uuid();
            let caller = get_caller_address();
            assert(attacks.len() <= 4, 'Too many attacks');
            assert(caller == erc721_owner_of(collection_address, token_id), 'Not Owner');
            if initiator.is_non_zero() {
                world.set_initiator(id, initiator);
            };
            world.create_lobby(id, receiver);
            world.set_game_info(id, time_limit, sender_id, 0);
            world.emit_lobby_created(id, caller, receiver);
            world
                .create_player_combatant(
                    sender_id, caller, id, collection_address, token_id, attacks,
                );
            return_value(id)
        }
        fn rescind_invite(ref self: ContractState, challenge_id: felt252) {
            let mut world = self.get_storage();
            world.assert_caller_sender(challenge_id);
            world.assert_lobby_open(challenge_id);
            world.close_lobby(challenge_id);
        }
        fn respond_invite(
            ref self: ContractState,
            challenge_id: felt252,
            token_id: u256,
            attacks: Array<(felt252, felt252)>,
        ) {
            let mut world = self.get_storage();
            let receiver = world.get_caller_receiver_from_open_lobby(challenge_id);
            let combatant_id = uuid();
            let sender_id = world.get_sender_combatant(challenge_id);

            let collection_address = world.get_combatant_token_address(sender_id);

            assert(attacks.len() <= 4, 'Too many attacks');
            assert(receiver == erc721_owner_of(collection_address, token_id), 'Not Owner');
            world
                .create_player_combatant(
                    combatant_id, receiver, challenge_id, collection_address, token_id, attacks,
                );
            world.set_game_combatants(challenge_id, sender_id, combatant_id);
        }

        fn reject_invite(ref self: ContractState, challenge_id: felt252) {
            let mut world = self.get_storage();
            world.get_caller_receiver_from_open_lobby(challenge_id);
            world.close_lobby(challenge_id);
        }

        fn rescind_response(ref self: ContractState, challenge_id: felt252) {
            let mut world = self.get_storage();
            world.get_caller_receiver_from_open_lobby(challenge_id);
            let (sender_id, receiver_id) = world.get_game_combatants(challenge_id);
            assert(receiver_id.is_non_zero(), 'No response');
            world.set_game_combatants(challenge_id, sender_id, 0);
        }

        fn accept_response(ref self: ContractState, challenge_id: felt252) {
            let mut world = self.get_storage();
            world.assert_caller_can_respond(challenge_id);
            if world.get_initiator(challenge_id).is_zero() {
                world.new_started_combat_state(challenge_id);
            } else {
                world.new_combat_state(challenge_id);
            }
        }

        fn reject_response(ref self: ContractState, challenge_id: felt252) {
            let mut world = self.get_storage();
            let sender_id = world.assert_caller_can_respond(challenge_id);
            world.set_game_combatants(challenge_id, sender_id, 0);
        }
    }
}
