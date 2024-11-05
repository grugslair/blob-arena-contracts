use core::poseidon::HashState;
use starknet::ContractAddress;
use dojo::{world::WorldStorage, model::ModelStorage};
use blob_arena::{
    combat::{CombatTrait, Phase}, attacks::{PlannedAttack, AttackTrait},
    pvp::{
        PvPChallengeInvite, PvPChallengeResponse, PvPChallenge, PvPCombatants, make_pvp_challenge,
        PvPChallengeScore, PvPChallengeScoreTrait
    },
    combatants::{CombatantTrait, CombatantState, CombatantInfo}, ab::{ABT, ABTTrait, ABTLogicTrait},
    hash::UpdateHashToU128
};


#[generate_trait]
impl PvPCombatImpl of PvPCombatTrait {
    fn run_pvp_round(
        ref self: WorldStorage,
        combatant_ids: ABT<felt252>,
        planned_attacks: ABT<PlannedAttack>,
        round: u32,
        hash: HashState
    ) -> Array<CombatantState> {
        let state_a = self.get_combatant_state(combatant_ids.a);
        let state_b = self.get_combatant_state(combatant_ids.b);
        let attack_a = @self.get_attack(planned_attacks.a.attack);
        let attack_b = @self.get_attack(planned_attacks.b.attack);
        let speed_a = self.get_attacker_attack_speed(@state_a, attack_a);
        let speed_b = self.get_attacker_attack_speed(@state_b, attack_b);

        let switch = if speed_a == speed_b {
            (hash.to_u128() % 2_u128) == 1
        } else {
            speed_a < speed_b
        };
        let (mut state_1, mut state_2, attack_1, attack_2) = if switch {
            (state_b, state_a, attack_b, attack_a)
        } else {
            (state_a, state_b, attack_a, attack_b)
        };

        self.run_attack(ref state_1, ref state_2, attack_1, round, hash);
        if state_1.health > 0 && state_2.health > 0 {
            self.run_attack(ref state_2, ref state_1, attack_2, round, hash);
        }
        self.write_model(@state_1);
        self.write_model(@state_2);

        array![state_1, state_2]
    }
}


#[generate_trait]
impl PvPChallengeImpl of PvPTrait {
    fn get_challenge_invite(self: @WorldStorage, challenge_id: felt252) -> PvPChallengeInvite {
        self.read_model(challenge_id)
    }

    fn get_challenge_response(self: @WorldStorage, challenge_id: felt252) -> PvPChallengeResponse {
        self.read_model(challenge_id)
    }


    fn send_challenge_invite(
        ref self: WorldStorage,
        challenge_id: felt252,
        sender: ContractAddress,
        receiver: ContractAddress,
        collection_address: ContractAddress,
        combatant_id: felt252,
        phase_time: u64,
    ) {
        self
            .write_model(
                @PvPChallengeInvite {
                    id: challenge_id,
                    sender,
                    receiver,
                    collection_address,
                    combatant: combatant_id,
                    phase_time,
                    open: true,
                }
            );
    }


    fn get_challenge(self: @WorldStorage, challenge_id: felt252) -> PvPChallenge {
        make_pvp_challenge(
            @self.get_challenge_invite(challenge_id), @self.get_challenge_response(challenge_id)
        )
    }

    fn get_open_challenge(self: @WorldStorage, challenge_id: felt252) -> PvPChallenge {
        let challenge = self.get_challenge(challenge_id);
        assert(challenge.invite_open, 'Challenge already closed');

        assert(self.get_combat_phase(challenge_id) == Phase::Setup, 'Combat already started');
        challenge
    }


    fn create_game(ref self: WorldStorage, challenge: @PvPChallenge) {
        self
            .set_pvp_combatants(
                *challenge.id, (*challenge.sender_combatant, *challenge.receiver_combatant)
            );
        self.new_combat_state(*challenge.id);
    }

    fn set_pvp_combatants(ref self: WorldStorage, id: felt252, combatants: (felt252, felt252)) {
        self.write_model(@PvPCombatants { id, combatants: combatants });
    }
    fn get_pvp_combatants_model(self: @WorldStorage, id: felt252) -> PvPCombatants {
        self.read_model(id)
    }
    fn get_pvp_combatants(self: @WorldStorage, id: felt252) -> ABT<felt252> {
        let combatants = ABTTrait::new_from_tuple(self.get_pvp_combatants_model(id).combatants);
        assert(combatants.is_neither_zero(), 'Combatants not set');
        combatants
    }
    fn get_pvp_score(
        self: @WorldStorage,
        player: ContractAddress,
        collection_address: ContractAddress,
        token_id: u256
    ) -> PvPChallengeScore {
        self.read_model((player, collection_address, token_id.high, token_id.low))
    }

    fn update_pvp_scores(ref self: WorldStorage, winner: CombatantInfo, loser: CombatantInfo) {
        let mut winner_score = self
            .get_pvp_score(winner.player, winner.collection_address, winner.token_id);
        let mut loser_score = self
            .get_pvp_score(loser.player, loser.collection_address, loser.token_id);
        winner_score.win();
        loser_score.lose();
        self.write_model(@winner_score);
        self.write_model(@loser_score);
    }
}
