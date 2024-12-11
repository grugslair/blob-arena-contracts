use starknet::{get_block_timestamp, get_caller_address, ContractAddress};
use dojo::{world::WorldStorage, model::{ModelStorage, Model}, event::EventStorage};
use blob_arena::{
    game::{components::{LastTimestamp, Initiator, GameInfo, GameInfoTrait}, storage::GameStorage},
    combat::{CombatTrait, Phase, CombatState, CombatStorage, components::PhaseTrait},
    commitments::Commitment, utils::get_transaction_hash, combatants::CombatantTrait, salts::Salts,
    hash::in_order, attacks::results::RoundResult, core::TTupleSized2ToSpan
};

#[generate_trait]
impl GameImpl of GameTrait {
    fn create_game(
        ref self: WorldStorage,
        owner: ContractAddress,
        initiator: ContractAddress,
        time_limit: u64,
        player_a: ContractAddress,
        collection_address_a: ContractAddress,
        token_id_a: u256,
        attacks_a: Span<(felt252, felt252)>,
        player_b: ContractAddress,
        collection_address_b: ContractAddress,
        token_id_b: u256,
        attacks_b: Span<(felt252, felt252)>,
    ) -> felt252 {
        let combat_id = get_transaction_hash();
        let combatant_a = self
            .create_combatant(collection_address_a, token_id_a, combat_id, player_a, attacks_a);
        let combatant_b = self
            .create_combatant(collection_address_b, token_id_b, combat_id, player_b, attacks_b);
        let game_info = GameInfo {
            combat_id, owner, time_limit, combatant_ids: (combatant_a, combatant_b),
        };
        self.set_initiator(combat_id, initiator);
        self.write_model(@game_info);
        self.new_combat_state(combat_id);
        combat_id
    }
    fn assert_caller_initiator(self: @WorldStorage, game_id: felt252) {
        assert(self.get_initiator(game_id) == get_caller_address(), 'Not the initiator');
    }
    fn assert_past_time_limit(self: @WorldStorage, game: GameInfo) {
        assert(game.time_limit.is_non_zero(), 'No time limit set');
        assert(
            get_block_timestamp() - self.get_last_timestamp(game.combat_id) > game.time_limit,
            'Not past time limit'
        );
    }

    fn run_round(ref self: WorldStorage, game: GameInfo) {
        let mut combat = self.get_combat_state(game.combat_id);
        combat.phase.assert_reveal();
        let combatants_span = game.combatant_ids.span();
        assert(self.check_commitments_unset_with(combatants_span), 'Not all attacks revealed');
        let array = self.get_states_and_attacks(combatants_span);

        let hash = self.get_salts_hash_state(combat.id);

        let ((mut state_1, attack_1), (mut state_2, attack_2)) = if in_order(
            array.at(0).get_speed(), array.at(1).get_speed(), hash
        ) {
            (*array.at(0), *array.at(1))
        } else {
            (*array.at(1), *array.at(0))
        };
        let mut results = array![];

        results.append(self.run_attack(ref state_1, ref state_2, @attack_1, combat.round, hash));
        if state_1.health > 0 && state_2.health > 0 {
            results
                .append(self.run_attack(ref state_2, ref state_1, @attack_2, combat.round, hash));
        };
        self
            .emit_event(
                @RoundResult { combat_id: combat.id, round: combat.round, attacks: results.span() }
            );

        match (state_1.health > 0, state_2.health > 0) {
            (true, true) => { self.next_round(ref combat, combatants_span); },
            (false, true) => { combat.phase = Phase::Ended(state_2.id); },
            _ => { combat.phase = Phase::Ended(state_1.id); }
        };
    }
}

