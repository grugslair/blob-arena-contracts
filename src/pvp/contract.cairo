use starknet::ContractAddress;

#[starknet::interface]
trait IPvPAdminActions {
    fn create_challenge(
        ref self: ContractState,
        collection_address_a: ContractAddress,
        collection_address_b: ContractAddress,
        player_a: ContractAddress,
        player_b: ContractAddress,
        token_a_id: u256,
        token_b_id: u256,
        attacks_a: Span<(felt252, felt252)>,
        attacks_b: Span<(felt252, felt252)>,
    ) -> felt252;
    fn set_winner(ref self: ContractState, combatant_id: felt252);
}

#[starknet::interface]
trait IPvPCombatActions {
    fn commit_attack(ref self: ContractState, combatant_id: felt252, hash: felt252);
    fn reveal_attack(
        ref self: ContractState, combatant_id: felt252, attack: felt252, salt: felt252
    );
    fn run_round(ref self: ContractState, combat_id: felt252);
    fn forfeit(ref self: ContractState, combatant_id: felt252);
    fn kick_inactive_player(ref self: ContractState, combatant_id: felt252);
}

#[starknet::interface]
trait IPvPChallengeActions {
    fn send_invite(
        ref self: ContractState,
        receiver: ContractAddress,
        collection_address: ContractAddress,
        token_id: u256,
        attacks: Span<(felt252, felt252)>,
        phase_time: u64
    ) -> felt252;
    fn rescind_invite(ref self: ContractState, challenge_id: felt252);
    fn respond_invite(
        ref self: ContractState,
        challenge_id: felt252,
        token_id: u256,
        attacks: Span<(felt252, felt252)>
    );
    fn rescind_response(ref self: ContractState, challenge_id: felt252);
    fn reject_invite(ref self: ContractState, challenge_id: felt252);
    fn reject_response(ref self: ContractState, challenge_id: felt252);
    fn accept_response(ref self: ContractState, challenge_id: felt252);
}


#[dojo::contract]
mod pvp_actions {
    use dojo::model::Model;
    use starknet::{ContractAddress, get_caller_address};
    use blob_arena::{pvp::{}, combatant::{}, hash::hash_value, uuid};
    use super::{IPvPCombatActions, IPvPChallengeActions};

    fn dojo_init(self: @ContractState, owner: Span<felt252>) {
        let world = self.world(default_namespace());
        world.set_permissions()
    }

    #[abi(embed_v0)]
    impl IPvPAdminActionsImpl of IPvPAdminActions<ContractState> {
        fn create_challenge(
            ref self: ContractState,
            collection_address_a: ContractAddress,
            collection_address_b: ContractAddress,
            player_a: ContractAddress,
            player_b: ContractAddress,
            token_a_id: u256,
            token_b_id: u256,
            attacks_a: Span<(felt252, felt252)>,
            attacks_b: Span<(felt252, felt252)>,
        ) -> felt252 {
            world.assert_caller_is_owner();
            let combat_id = uuid(world);
            let collection_a = get_collection_dispatcher(collection_address_a);
            let collection_b = get_collection_dispatcher(collection_address_b);
            let combatant_a = world
                .create_combatant(collection_a, token_a_id, combat_id, player_a, attacks_a);
            let combatant_b = world
                .create_combatant(collection_b, token_b_id, combat_id, player_b, attacks_b);
            world.new_combat_state(combat_id);
            world.set_pvp_combatants(combat_id, (combatant_a.id, combatant_b.id));
            combat_id
        }
        fn set_winner(ref self: ContractState, combatant_id: felt252) {
            world.assert_caller_is_owner();

            let winner = world.get_combatant_info(combatant_id);
            let mut combat = world.get_running_combat_state(winner.combat_id);
            let combatants = world.get_pvp_combatants(combat.id);
            let loser = world.get_combatant_info(combatants.other(winner.id));
            world.end_combat(combat, winner.id);
            world.update_scores(winner, loser);
        }
    }

    #[abi(embed_v0)]
    impl IPvPChallengeActionsImpl of IPvPChallengeActions<ContractState> {
        fn send_invite(
            ref self: ContractState,
            receiver: ContractAddress,
            collection_address: ContractAddress,
            token_id: u256,
            attacks: Span<(felt252, felt252)>,
            phase_time: u64,
        ) -> felt252 {
            let challenge_id = uuid(world);
            let caller = get_caller_address();
            let combatant = world
                .create_player_combatant(
                    collection_address, token_id, challenge_id, caller, attacks
                );
            world
                .send_challenge_invite(
                    challenge_id, caller, receiver, collection_address, combatant.id, phase_time,
                );
            challenge_id
        }
        fn rescind_invite(ref self: ContractState, challenge_id: felt252) {
            let mut challenge = world.get_open_challenge(challenge_id);
            challenge.assert_caller_sender();
            challenge.invite_open = false;
            world.write_model(challenge);
        }
        fn respond_invite(
            ref self: ContractState,
            challenge_id: felt252,
            token_id: u256,
            attacks: Span<(felt252, felt252)>
        ) {
            let mut challenge = world.get_open_challenge(challenge_id);
            assert(!challenge.response_open, 'Already responded');

            let caller = challenge.assert_caller_receiver();
            let combatant = world
                .create_player_combatant(
                    challenge.collection_address, token_id, challenge_id, caller, attacks
                );

            challenge.receiver_combatant = combatant.id;
            challenge.response_open = true;
            world.write_model(challenge);
        }
        fn rescind_response(ref self: ContractState, challenge_id: felt252) {
            let mut challenge = world.get_open_challenge(challenge_id);
            challenge.assert_caller_receiver();
            assert(challenge.response_open, 'Response already closed');
            challenge.response_open = false;
            world.write_model(challenge);
        }
        fn reject_invite(ref self: ContractState, challenge_id: felt252) {
            let mut challenge = world.get_open_challenge(challenge_id);
            challenge.assert_caller_receiver();
            challenge.invite_open = false;
            world.write_model(challenge);
        }
        fn reject_response(ref self: ContractState, challenge_id: felt252) {
            let mut challenge = world.get_open_challenge(challenge_id);
            challenge.assert_caller_sender();
            challenge.invite_open = false;
            world.write_model(challenge);
        }
        fn accept_response(ref self: ContractState, challenge_id: felt252) {
            let mut challenge = world.get_open_challenge(challenge_id);
            challenge.assert_caller_sender();
            assert(challenge.response_open, 'Response already closed');
            world.create_game(challenge);
        }
    }
    #[abi(embed_v0)]
    impl PvPActionsImpl of IPvPCombatActions<ContractState> {
        fn commit_attack(ref self: ContractState, combatant_id: felt252, hash: felt252) {
            let combatant = world.get_combatant_info_in_combat(combatant_id);
            let combat = world.get_combat_state(combatant.combat_id);
            assert(combat.phase == Phase::Commit, 'Not in commit phase');

            combatant.assert_player();
            world.set_new_commitment_with(combatant_id, hash);
        }
        fn reveal_attack(
            ref self: ContractState, combatant_id: felt252, attack: felt252, salt: felt252
        ) {
            let combatant = world.get_combatant_info_in_combat(combatant_id);
            combatant.assert_player();
            let mut combat = world.get_combat_state(combatant.combat_id);
            let combatants = world.get_pvp_combatants(combat.id);
            if combat.phase == Phase::Commit {
                if world.check_commitments_set_with(combatants.into()) {
                    combat.phase = Phase::Reveal;
                    set!(world, (combat,))
                };
            };
            assert(combat.phase == Phase::Reveal, 'Not in reveal phase');
            let hash = hash_value((attack, salt));
            let commitment = world.get_commitment_with(combatant_id);
            if hash == commitment {
                world.append_salt(combat.id, salt);
                let other_combatant = combatants.other(combatant_id);
                PlannedAttack { id: combatant_id, attack, target: other_combatant, }.set(world);
            } else {
                let winner_id = combatants.other(combatant_id);
                world.end_combat(combat, winner_id);
                world.update_scores(world.get_combatant_info(winner_id), combatant);
            }
        }
        fn run_round(ref self: ContractState, combat_id: felt252) {
            let mut combat = world.get_running_combat_state(combat_id);
            let combatants = world.get_pvp_combatants(combat_id);
            let combatants_span: Span<felt252> = combatants.into();
            assert(combat.phase == Phase::Reveal, 'Not in reveal phase');
            let hash = world.get_salts_hash_state(combat_id);
            let planned_attacks = world.get_planned_attacks(combatants_span);
            assert(planned_attacks.check_all_set(), 'Not all attacks revealed');
            let states = world
                .run_round(combatants, planned_attacks.try_into().unwrap(), combat.round, hash);
            let (alive, dead) = states.get_combatants_mortality();
            if (alive.len() > 1) {
                world.next_round(combat, combatants_span);
            } else {
                let winner_id = *alive.at(0);
                let winner = world.get_combatant_info(winner_id);
                let looser = world.get_combatant_info(*dead.at(0));

                world.end_combat(combat, winner_id);
                world.update_scores(winner, looser);
            }
        }
        fn forfeit(ref self: ContractState, combatant_id: felt252) {
            let loser = world.get_combatant_info_in_combat(combatant_id);
            loser.assert_player();
            let mut combat = world.get_running_combat_state(loser.combat_id);
            let combatants = world.get_pvp_combatants(combat.id);
            let winner_id = combatants.other(loser.id);
            let winner = world.get_combatant_info(winner_id);
            world.end_combat(combat, winner_id);
            world.update_scores(winner, loser);
        }
        fn kick_inactive_player(
            ref self: ContractState, combatant_id: felt252
        ) { // let mut combat = world.get_combat_state(combat_id);
        }
    }
}
