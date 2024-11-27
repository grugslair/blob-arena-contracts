use starknet::ContractAddress;

#[starknet::interface]
trait IPvPAdminActions<TContractState> {
    fn create_challenge(
        ref self: TContractState,
        collection_address_a: ContractAddress,
        collection_address_b: ContractAddress,
        player_a: ContractAddress,
        player_b: ContractAddress,
        token_a_id: u256,
        token_b_id: u256,
        attacks_a: Span<(felt252, felt252)>,
        attacks_b: Span<(felt252, felt252)>,
    ) -> felt252;
    fn set_winner(ref self: TContractState, combatant_id: felt252);
}

#[starknet::interface]
trait IPvPCombatActions<TContractState> {
    fn commit_attack(ref self: TContractState, combatant_id: felt252, hash: felt252);
    fn reveal_attack(
        ref self: TContractState, combatant_id: felt252, attack: felt252, salt: felt252
    );
    fn run_round(ref self: TContractState, combat_id: felt252);
    fn forfeit(ref self: TContractState, combatant_id: felt252);
    fn kick_inactive_player(ref self: TContractState, combatant_id: felt252);
}

#[starknet::interface]
trait IPvPChallengeActions<TContractState> {
    fn send_invite(
        ref self: TContractState,
        receiver: ContractAddress,
        collection_address: ContractAddress,
        token_id: u256,
        attacks: Span<(felt252, felt252)>,
        phase_time: u64
    ) -> felt252;
    fn rescind_invite(ref self: TContractState, challenge_id: felt252);
    fn respond_invite(
        ref self: TContractState,
        challenge_id: felt252,
        token_id: u256,
        attacks: Span<(felt252, felt252)>
    );
    fn rescind_response(ref self: TContractState, challenge_id: felt252);
    fn reject_invite(ref self: TContractState, challenge_id: felt252);
    fn reject_response(ref self: TContractState, challenge_id: felt252);
    fn accept_response(ref self: TContractState, challenge_id: felt252);
}


#[dojo::contract]
mod pvp_actions {
    const SELECTOR: felt252 = selector!("blob_arena-pvp_actions");
    use dojo::{model::ModelStorage, event::EventStorage};
    use starknet::{ContractAddress, get_caller_address};
    use blob_arena::{
        attacks::{PlannedAttack, PlannedAttackTrait, PlannedAttacksTrait, results::RoundResult},
        pvp::{PvPChallengeTrait, PvPTrait, PvPChallengeScoreTrait, PvPCombatTrait},
        combatants::{CombatantTrait, CombatantInfoTrait}, hash::hash_value,
        combat::{CombatTrait, Phase}, world::{WorldTrait, default_namespace, uuid},
        ab::{ABTTrait, ABTOtherTrait}, commitments::Commitment, salts::Salts
    };
    use super::{IPvPCombatActions, IPvPChallengeActions, IPvPAdminActions};


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
            let mut world = self.world(default_namespace());
            world.assert_caller_is_admin(SELECTOR);
            let combat_id = uuid();
            let combatant_a = world
                .create_combatant(collection_address_a, token_a_id, combat_id, player_a, attacks_a);
            let combatant_b = world
                .create_combatant(collection_address_b, token_b_id, combat_id, player_b, attacks_b);
            world.new_combat_state(combat_id);
            world.set_pvp_combatants(combat_id, (combatant_a.id, combatant_b.id));
            combat_id
        }
        fn set_winner(ref self: ContractState, combatant_id: felt252) {
            let mut world = self.world(default_namespace());
            world.assert_caller_is_admin(SELECTOR);

            let winner = world.get_combatant_info(combatant_id);
            let mut combat = world.get_running_combat_state(winner.combat_id);
            let combatants = world.get_pvp_combatants(combat.id);
            let loser = world.get_combatant_info(combatants.other(winner.id));
            world.end_combat(combat, winner.id);
            world.update_pvp_scores(winner, loser);
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
            assert(attacks.len() <= 4, 'Too many attacks');
            let mut world = self.world(default_namespace());
            let challenge_id = uuid();
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
            let mut world = self.world(default_namespace());

            let mut challenge = world.get_open_challenge(challenge_id);
            challenge.assert_caller_sender();
            challenge.invite_open = false;
            world.write_model(@(challenge.invite()));
        }
        fn respond_invite(
            ref self: ContractState,
            challenge_id: felt252,
            token_id: u256,
            attacks: Span<(felt252, felt252)>
        ) {
            assert(attacks.len() <= 4, 'Too many attacks');

            let mut world = self.world(default_namespace());
            let mut challenge = world.get_open_challenge(challenge_id);
            assert(!challenge.response_open, 'Already responded');

            let caller = challenge.assert_caller_receiver();
            let combatant = world
                .create_player_combatant(
                    challenge.collection_address, token_id, challenge_id, caller, attacks
                );

            challenge.receiver_combatant = combatant.id;
            challenge.response_open = true;
            world.write_model(@(challenge.response()));
        }
        fn rescind_response(ref self: ContractState, challenge_id: felt252) {
            let mut world = self.world(default_namespace());
            let mut challenge = world.get_open_challenge(challenge_id);
            challenge.assert_caller_receiver();
            assert(challenge.response_open, 'Response already closed');
            challenge.response_open = false;
            world.write_model(@challenge.response());
        }
        fn reject_invite(ref self: ContractState, challenge_id: felt252) {
            let mut world = self.world(default_namespace());
            let mut challenge = world.get_open_challenge(challenge_id);
            challenge.assert_caller_receiver();
            challenge.invite_open = false;
            world.write_model(@challenge.invite());
        }
        fn reject_response(ref self: ContractState, challenge_id: felt252) {
            let mut world = self.world(default_namespace());
            let mut challenge = world.get_open_challenge(challenge_id);
            challenge.assert_caller_sender();
            challenge.invite_open = false;
            world.write_model(@challenge.invite());
        }
        fn accept_response(ref self: ContractState, challenge_id: felt252) {
            let mut world = self.world(default_namespace());
            let mut challenge = world.get_open_challenge(challenge_id);
            challenge.assert_caller_sender();
            assert(challenge.response_open, 'Response already closed');
            world.create_game(@challenge);
        }
    }

    #[abi(embed_v0)]
    impl PvPActionsImpl of IPvPCombatActions<ContractState> {
        fn commit_attack(ref self: ContractState, combatant_id: felt252, hash: felt252) {
            let mut world = self.world(default_namespace());
            let combatant = world.get_combatant_info_in_combat(combatant_id);
            let combat = world.get_combat_state(combatant.combat_id);
            assert(combat.phase == Phase::Commit, 'Not in commit phase');

            combatant.assert_player();
            world.set_new_commitment_with(combatant_id, hash);
        }
        fn reveal_attack(
            ref self: ContractState, combatant_id: felt252, attack: felt252, salt: felt252
        ) {
            let mut world = self.world(default_namespace());

            let combatant = world.get_combatant_info_in_combat(combatant_id);
            combatant.assert_player();
            let mut combat = world.get_combat_state(combatant.combat_id);
            let combatants = world.get_pvp_combatants(combat.id);
            if combat.phase == Phase::Commit
                && world.check_commitments_set_with(combatants.into()) {
                world.set_combat_phase(combat.id, Phase::Reveal);
            };

            assert(combat.phase == Phase::Reveal, 'Not in reveal phase');
            let commitment = world.get_commitment_with(combatant_id);

            if hash_value((attack, salt)) == commitment {
                world.append_salt(combat.id, salt);
                world.set_planned_attack(combatant_id, attack, combatants.other(combatant_id));
            } else {
                let winner_id = combatants.other(combatant_id);
                world.end_combat(combat, winner_id);
                world.update_pvp_scores(world.get_combatant_info(winner_id), combatant);
            }
        }
        fn run_round(ref self: ContractState, combat_id: felt252) {
            let mut world = self.world(default_namespace());
            let mut combat = world.get_running_combat_state(combat_id);
            let combatants = world.get_pvp_combatants(combat_id);
            let combatants_span: Span<felt252> = combatants.into();
            assert(combat.phase == Phase::Reveal, 'Not in reveal phase');
            let hash = world.get_salts_hash_state(combat_id);
            let planned_attacks = world.get_planned_attacks(combatants_span);
            assert(planned_attacks.check_all_set(), 'Not all attacks revealed');

            let (states, attack_result) = world.run_pvp_round(planned_attacks, combat.round, hash);
            world
                .emit_event(
                    @RoundResult { combat_id, round: combat.round, attacks: attack_result }
                );
            let (alive, dead) = states.get_combatants_mortality();
            if (alive.len() > 1) {
                world.next_round(combat, combatants_span);
            } else {
                let winner_id = *alive.at(0);
                let winner = world.get_combatant_info(winner_id);
                let looser = world.get_combatant_info(*dead.at(0));

                world.end_combat(combat, winner_id);
                world.update_pvp_scores(winner, looser);
            }
        }
        fn forfeit(ref self: ContractState, combatant_id: felt252) {
            let mut world = self.world(default_namespace());
            let loser = world.get_combatant_info_in_combat(combatant_id);
            loser.assert_player();
            let mut combat = world.get_running_combat_state(loser.combat_id);
            let combatants = world.get_pvp_combatants(combat.id);
            let winner_id = combatants.other(loser.id);
            let winner = world.get_combatant_info(winner_id);
            world.end_combat(combat, winner_id);
            world.update_pvp_scores(winner, loser);
        }
        fn kick_inactive_player(
            ref self: ContractState, combatant_id: felt252
        ) { // let mut combat = world.get_combat_state(combat_id);
        }
    }
}
