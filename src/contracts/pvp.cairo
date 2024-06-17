use starknet::ContractAddress;
use dojo::world::{IWorldDispatcher};

#[starknet::interface]
trait IPvPCombatActions<TContractState> {
    fn commit_attack(
        self: @TContractState,
        world: IWorldDispatcher,
        combat_id: u128,
        warrior_id: u128,
        hash: felt252
    );
    fn reveal_attack(
        self: @TContractState,
        world: IWorldDispatcher,
        combat_id: u128,
        warrior_id: u128,
        attack: u128,
        salt: felt252
    );
    fn forfeit(self: @TContractState, world: IWorldDispatcher, combat_id: u128, warrior_id: u128);
    fn kick_inactive_player(
        self: @TContractState, world: IWorldDispatcher, combat_id: u128, warrior_id: u128
    );
}

#[starknet::interface]
trait IPvPChallengeActions<TContractState> {
    fn send_invite(
        self: @TContractState,
        world: IWorldDispatcher,
        receiver: ContractAddress,
        token_id: u256,
        phase_time: u64,
        collection_address: ContractAddress,
    ) -> u128;
    fn rescind_invite(self: @TContractState, world: IWorldDispatcher, challenge_id: u128);
    fn respond_invite(
        self: @TContractState, world: IWorldDispatcher, challenge_id: u128, token_id: u256
    );
    fn rescind_response(self: @TContractState, world: IWorldDispatcher, challenge_id: u128);
    fn reject_invite(self: @TContractState, world: IWorldDispatcher, challenge_id: u128);
    fn reject_response(self: @TContractState, world: IWorldDispatcher, challenge_id: u128);
    fn accept_response(self: @TContractState, world: IWorldDispatcher, challenge_id: u128);
}


#[starknet::contract]
mod pvp_actions {
    use starknet::{ContractAddress, get_caller_address};
    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};
    use blob_arena::{
        components::{
            combat::{SaltsTrait, Phase},
            combatant::{CombatantInfo, CombatantAttributes, CombatantTrait},
            commitment::{Commitment,},
            pvp_combat::{PvPCombatTrait, ABStateTrait, ABCombatantTrait, PvPPhase, PvPWinner},
            pvp_challenge::{PvPChallengeTrait, PvPChallengeInvite, PvPChallengeScoreTrait},
            utils::ABTTrait, warrior::{Warrior, WarriorTrait, get_warrior_id},
        },
        utils::{uuid, hash_value},
    };
    use super::{IPvPCombatActions, IPvPChallengeActions};
    use core::hash::TupleSize2Hash;

    #[storage]
    struct Storage {}

    #[generate_trait]
    impl Private of PrivateTrait {
        fn setup_combatant(
            self: IWorldDispatcher,
            collection_address: ContractAddress,
            token_id: u256,
            challenge_id: u128,
            player: ContractAddress
        ) -> CombatantInfo {
            let warrior_id = get_warrior_id(collection_address, token_id);
            let warrior = self.get_warrior(warrior_id);
            assert(player == warrior.owner, 'Not Owner');
            self.create_combatant(warrior, challenge_id)
        }
    }


    #[abi(embed_v0)]
    impl IPvPChallengeActionsImpl of IPvPChallengeActions<ContractState> {
        fn send_invite(
            self: @ContractState,
            world: IWorldDispatcher,
            receiver: ContractAddress,
            token_id: u256,
            phase_time: u64,
            collection_address: ContractAddress
        ) -> u128 {
            let challenge_id: u128 = uuid(world);
            let caller = get_caller_address();
            let combatant = world
                .setup_combatant(collection_address, token_id, challenge_id, caller);

            world
                .send_challenge_invite(
                    challenge_id,
                    caller,
                    receiver,
                    combatant.warrior_id,
                    phase_time,
                    collection_address
                );
            challenge_id
        }
        fn rescind_invite(self: @ContractState, world: IWorldDispatcher, challenge_id: u128) {
            let mut challenge = world.get_open_challenge(challenge_id);
            challenge.assert_caller_sender();
            challenge.invite_open = false;
            world.set_challenge_invite(challenge);
        }
        fn respond_invite(
            self: @ContractState, world: IWorldDispatcher, challenge_id: u128, token_id: u256
        ) {
            let mut challenge = world.get_open_challenge(challenge_id);
            assert(!challenge.response_open, 'Already responded');

            let caller = challenge.assert_caller_receiver();
            let combatant = world
                .setup_combatant(challenge.collection_address, token_id, challenge_id, caller);

            challenge.receiver_warrior = combatant.warrior_id;
            challenge.response_open = true;
            world.set_challenge_response(challenge);
        }
        fn rescind_response(self: @ContractState, world: IWorldDispatcher, challenge_id: u128) {
            let mut challenge = world.get_open_challenge(challenge_id);
            challenge.assert_caller_receiver();
            assert(challenge.response_open, 'Response already closed');
            challenge.response_open = false;
            world.set_challenge_response(challenge);
        }
        fn reject_invite(self: @ContractState, world: IWorldDispatcher, challenge_id: u128) {
            let mut challenge = world.get_open_challenge(challenge_id);
            challenge.assert_caller_receiver();
            challenge.invite_open = false;
            world.set_challenge_invite(challenge);
        }
        fn reject_response(self: @ContractState, world: IWorldDispatcher, challenge_id: u128) {
            let mut challenge = world.get_open_challenge(challenge_id);
            challenge.assert_caller_receiver();
            challenge.invite_open = false;
            world.set_challenge_invite(challenge);
        }
        fn accept_response(self: @ContractState, world: IWorldDispatcher, challenge_id: u128) {
            let mut challenge = world.get_open_challenge(challenge_id);
            challenge.assert_caller_sender();
            assert(challenge.response_open, 'Response already closed');
            world.create_game(challenge);
        }
    }

    #[abi(embed_v0)]
    impl PvPActionsImpl of IPvPCombatActions<ContractState> {
        fn commit_attack(
            self: @ContractState,
            world: IWorldDispatcher,
            combat_id: u128,
            warrior_id: u128,
            hash: felt252
        ) {
            let mut combat = world.get_pvp_combat(combat_id);
            assert(combat.phase == Phase::Commit, 'Not in commit phase');

            let ab = combat.combatants.get_combatant_ab(warrior_id);
            let combatant = combat.combatants.get(ab);

            combatant.assert_player();
            assert(combat.players_state.get(ab), 'Attack Already Committed');
            let set = combat.players_state.get(!ab);

            world.set_commitment_with((combat_id, warrior_id), hash);
            if set {
                combat.players_state.set(!ab, false);
                combat.phase = Phase::Reveal;
            } else {
                combat.players_state.set(ab, true);
            }
            world.set_pvp_combat_state(combat);
        }
        fn reveal_attack(
            self: @ContractState,
            world: IWorldDispatcher,
            combat_id: u128,
            warrior_id: u128,
            attack: u128,
            salt: felt252
        ) {
            let mut combat = world.get_pvp_combat(combat_id);
            assert(combat.phase == Phase::Reveal, 'Not in reveal phase');
            let ab = combat.combatants.get_combatant_ab(warrior_id);
            let combatant = combat.combatants.get(ab);
            combatant.assert_player();
            assert(combat.players_state.get(ab), 'Attack Already Revealed');
            let hash = hash_value((attack, salt));
            let commitment = world.get_commitment_with((combat_id, warrior_id));
            if hash == commitment {
                world.append_salt(combat_id, salt);
                world.set_planned_attack(combat_id, warrior_id, attack);
                if combat.players_state.get(!ab) {

                    combat.run_round();
                    combat.phase = Phase::Commit;
                    combat.players_state.set(!ab, false);
                } else {
                    combat.phase = Phase::Resolve;
                }
            } else {
                world.end_game(combat_id, (!ab).into());
            }
        }
        fn forfeit(
            self: @ContractState, world: IWorldDispatcher, combat_id: u128, warrior_id: u128
        ) {
            let mut combat = world.get_pvp_combat(combat_id);
            combat.assert_running();
            let ab = combat.combatants.get_combatant_ab(warrior_id);
            let combatant = combat.combatants.get(ab);
            combatant.assert_player();
            let winner: PvPWinner = (!ab).into();
            world.end_game(combat_id, winner);
            world.update_scores(combat.combatants, winner);
        }
        fn kick_inactive_player(
            self: @ContractState, world: IWorldDispatcher, combat_id: u128, warrior_id: u128
        ) {
            let mut combat = world.get_pvp_combat(combat_id);
        }
    }
}
