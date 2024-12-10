use starknet::{get_block_timestamp, get_caller_address, ContractAddress};
use dojo::{world::WorldStorage, model::{ModelStorage, Model}};
use blob_arena::{
    betsy::components::{LastTimestamp, TimeLimit, Winner, Player}, combat::{CombatTrait, Phase},
    commitments::Commitment,
};

#[generate_trait]
impl BetsyImpl of BetsyTrait {
    fn get_time_limit(self: @WorldStorage, game_id: felt252) -> u64 {
        self.read_member(Model::<TimeLimit>::ptr_from_keys(game_id), selector!("time_limit"))
    }

    fn get_last_timestamp(self: @WorldStorage, game_id: felt252) -> u64 {
        self.read_member(Model::<LastTimestamp>::ptr_from_keys(game_id), selector!("timestamp"))
    }

    fn set_time_limit(ref self: WorldStorage, game_id: felt252, time_limit: u64) {
        self.write_model(@TimeLimit { game_id, time_limit });
    }

    fn set_last_timestamp(ref self: WorldStorage, game_id: felt252) {
        self.write_model(@LastTimestamp { game_id, timestamp: get_block_timestamp() });
    }

    fn assert_past_time_limit(self: @WorldStorage, game_id: felt252) {
        let last_timestamp = self.get_last_timestamp(game_id);
        let time_limit = self.get_time_limit(game_id);
        assert(last_timestamp.is_non_zero() && time_limit.is_non_zero(), 'Not started');
        assert(
            get_block_timestamp() - self.get_last_timestamp(game_id) > self.get_time_limit(game_id),
            'Not past time limit'
        );
    }

    fn set_player(
        ref self: WorldStorage, combatant_id: felt252, contract_address: ContractAddress
    ) {
        self.write_model(@Player { combatant_id, contract_address });
    }

    fn get_winner(self: @WorldStorage, game_id: felt252) -> ContractAddress {
        self.read_member(Model::<Winner>::ptr_from_keys(game_id), selector!("winner"))
    }

    fn set_winner(ref self: WorldStorage, game_id: felt252, winner: ContractAddress) {
        self.write_model(@Winner { game_id, winner });
    }

    fn assert_no_winner(self: @WorldStorage, game_id: felt252) {
        assert(self.get_winner(game_id).is_zero(), 'Already has a winner');
    }

    fn get_player(self: @WorldStorage, combatant_id: felt252) -> ContractAddress {
        self
            .read_member(
                Model::<Player>::ptr_from_keys(combatant_id), selector!("contract_address")
            )
    }

    fn assert_caller_combatant(self: @WorldStorage, combatant_id: felt252) {
        assert(self.get_player(combatant_id) == get_caller_address(), 'Not player');
    }

    fn get_states(
        self: @WorldStorage, combat_id: felt252, combatant_a_id: felt252, combatant_b_id: felt252
    ) -> (bool, bool) {
        match self.get_combat_phase(combat_id) {
            Phase::Commit => (
                self.check_commitment_set(combatant_a_id), self.check_commitment_set(combatant_b_id)
            ),
            Phase::Reveal => (
                self.check_commitment_unset(combatant_a_id),
                self.check_commitment_unset(combatant_b_id)
            ),
            _ => panic!("Not in play phase")
        }
    }
}
