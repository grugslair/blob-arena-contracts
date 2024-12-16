use starknet::ContractAddress;

#[starknet::interface]
trait ILobby<TContractState> {
    fn send_invite(
        ref self: TContractState,
        owner: ContractAddress,
        initiator: ContractAddress,
        time_limit: u64,
        receiver: ContractAddress,
        collection_address: ContractAddress,
        token_id: u256,
        attacks: Array<(felt252, felt252)>
    ) -> felt252;
    fn rescind_invite(ref self: TContractState, challenge_id: felt252);
    fn respond_invite(
        ref self: TContractState,
        challenge_id: felt252,
        token_id: u256,
        attacks: Array<(felt252, felt252)>
    );
    fn rescind_response(ref self: TContractState, challenge_id: felt252);
    fn reject_invite(ref self: TContractState, challenge_id: felt252);
    fn reject_response(ref self: TContractState, challenge_id: felt252);
    fn accept_response(ref self: TContractState, challenge_id: felt252);
}


#[dojo::contract]
mod lobby_actions {
    const SELECTOR: felt252 = selector!("blob_arena-pvp_actions");
    use starknet::{ContractAddress, get_caller_address};
    use dojo::world::WorldStorage;
    use blob_arena::{
        lobby::{systems::LobbyTrait, storage::LobbyStorage}, combat::{CombatTrait, CombatStorage},
        game::GameStorage, combatants::{CombatantTrait, CombatantStorage},
        utils::get_transaction_hash, hash::hash_value, world::{uuid, default_namespace}
    };
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
            owner: ContractAddress,
            initiator: ContractAddress,
            time_limit: u64,
            receiver: ContractAddress,
            collection_address: ContractAddress,
            token_id: u256,
            attacks: Array<(felt252, felt252)>
        ) -> felt252 {
            assert(attacks.len() <= 4, 'Too many attacks');
            let mut world = self.get_storage();

            let id = uuid();
            let sender_id = uuid();

            world.create_lobby(id, receiver);

            world.set_game_info(id, owner, time_limit, sender_id, 0);
            world.set_initiator(id, initiator);
            world
                .create_player_combatant(
                    sender_id, get_caller_address(), id, collection_address, token_id, attacks
                );
            id
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
            attacks: Array<(felt252, felt252)>
        ) {
            assert(attacks.len() <= 4, 'Too many attacks');

            let mut world = self.get_storage();
            let receiver = world.get_caller_receiver_from_open_lobby(challenge_id);
            let combatant_id = uuid();
            let sender_id = world.get_sender_combatant(challenge_id);

            let collection_address = world.get_combatant_token_address(sender_id);

            world
                .create_player_combatant(
                    combatant_id, receiver, challenge_id, collection_address, token_id, attacks
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
            world.new_combat_state(challenge_id);
        }

        fn reject_response(ref self: ContractState, challenge_id: felt252) {
            let mut world = self.get_storage();
            let sender_id = world.assert_caller_can_respond(challenge_id);
            world.set_game_combatants(challenge_id, sender_id, 0);
        }
    }
}
