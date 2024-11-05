use starknet::ContractAddress;
use dojo::{world::WorldStorage, model::ModelStorage};
use blob_arena::{
    combat::{CombatTrait, Phase},
    pvp::components::{PvPChallengeInvite, PvPChallengeResponse, PvPChallenge, PvPCombatantsModel}
};


#[generate_trait]
impl PvPCombatImpl of PvPCombatTrait {
    fn set_pvp_combatants<T, +Into<T, (felt252, felt252)>>(
        ref self: WorldStorage, id: felt252, combatants: T
    ) {
        self.write_model(@PvPCombatantsModel { id, combatants: combatants.into() });
    }
    fn get_pvp_combatants_model(self: @WorldStorage, id: felt252) -> PvPCombatantsModel {
        self.read_model(id)
    }
    fn get_pvp_combatants(self: @WorldStorage, id: felt252) -> ABT<felt252> {
        let combatants = ABTTrait::new_from_tuple(self.get_pvp_combatants_model(id).combatants);
        assert(combatants.is_neither_zero(), 'Combatants not set');
        combatants
    }
}


#[generate_trait]
impl PvPChallengeImpl of PvPChallengeTrait {
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
        make_challenge(
            self.get_challenge_invite(challenge_id), self.get_challenge_response(challenge_id)
        )
    }

    fn get_open_challenge(self: @WorldStorage, challenge_id: felt252) -> PvPChallenge {
        let challenge = self.get_challenge(challenge_id);
        assert(challenge.invite_open, 'Challenge already closed');

        assert(self.get_combat_phase(challenge_id) == Phase::Setup, 'Combat already started');
        challenge
    }


    fn create_game(ref self: WorldStorage, challenge: PvPChallenge) {
        self
            .set_pvp_combatants(
                challenge.id, (challenge.sender_combatant, challenge.receiver_combatant)
            );
        self.new_combat_state(challenge.id);
    }
}
