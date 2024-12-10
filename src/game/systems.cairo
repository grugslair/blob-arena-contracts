use core::poseidon::HashState;
use starknet::{ContractAddress, get_caller_address};
use dojo::{world::WorldStorage, model::{ModelStorage, Model}, event::EventStorage};

use blob_arena::{
    utils::get_transaction_hash, combatants::{CombatantState, CombatantTrait},
    combat::{CombatTrait, CombatState, Phase},
    attacks::{Attack, PlannedAttack, PlannedAttackTrait, results::RoundResult},
    hash::{in_order, hash_value}, game::components::Combatants, commitments::Commitment,
    salts::Salts
};

#[generate_trait]
impl GameImpl of GameTrait {
    fn create_game(
        ref self: WorldStorage,
        owner: ContractAddress,
        player_a: ContractAddress,
        collection_address_a: ContractAddress,
        token_id_a: u256,
        attacks_a: Span<(felt252, felt252)>,
        player_b: ContractAddress,
        collection_address_b: ContractAddress,
        token_id_b: u256,
        attacks_b: Span<(felt252, felt252)>,
    ) -> Combatants {
        let combat_id = get_transaction_hash();
        let combatant_a = self
            .create_combatant(collection_address_a, token_id_a, combat_id, player_a, attacks_a);
        let combatant_b = self
            .create_combatant(collection_address_b, token_id_b, combat_id, player_b, attacks_b);
        let combatants_model = Combatants { combat_id, combatant_ids: (combatant_a, combatant_b) };
        self.write_model(@combatants_model);
        self.new_combat_state(combat_id, owner);
        combatants_model
    }

    fn get_owners_combat_state(
        self: @WorldStorage, combat_id: felt252, caller: ContractAddress
    ) -> CombatState {
        let combat = self.get_combat_state(combat_id);
        assert(combat.owner == caller, 'Not the owner');
        combat
    }

    fn get_owners_combat_state_from_combatant_id(
        self: @WorldStorage, combatant_id: felt252, caller: ContractAddress
    ) -> CombatState {
        self.get_owners_combat_state(self.get_combat_id_from_combatant_id(combatant_id), caller)
    }

    fn get_combatants(self: @WorldStorage, combat_id: felt252) -> [felt252; 2] {
        self.read_member(Model::<Combatants>::ptr_from_keys(combat_id), selector!("combatant_ids"))
    }

    fn get_opponent_id(self: @WorldStorage, combat_id: felt252, combatant_id: felt252) -> felt252 {
        let [a, b] = self.get_combatants(combat_id);
        if combatant_id == a {
            b
        } else if combatant_id == b {
            a
        } else {
            panic!("Combatant not in combat")
        }
    }


    fn get_speed(self: @(CombatantState, Attack)) -> u8 {
        let (state, attack) = self;
        *state.stats.dexterity + *attack.speed
    }

    fn commit_attack(
        ref self: WorldStorage, ref combat: CombatState, combatant_id: felt252, hash: felt252
    ) {
        assert(combat.phase == Phase::Commit, 'Not in commit phase');
        self.set_new_commitment(combatant_id, hash);
        let opponent_id = self.get_opponent_id(combat.id, combatant_id);
        if self.check_commitment_set(opponent_id) {
            combat.phase = Phase::Reveal;
            self.write_model(@combat);
        }
    }

    fn reveal_attack(
        ref self: WorldStorage,
        ref combat: CombatState,
        combatant_id: felt252,
        attack: felt252,
        salt: felt252
    ) {
        assert(combat.phase == Phase::Reveal, 'Not in reveal phase');

        let commitment = self.consume_commitment(combatant_id);
        if hash_value((attack, salt)) == commitment {
            self.append_salt(combat.id, salt);
            self
                .set_planned_attack(
                    combatant_id, attack, self.get_opponent_id(combat.id, combatant_id)
                );
        } else {
            self.end_combat(ref combat, self.get_opponent_id(combat.id, combatant_id));
        }
    }


    fn run_round(ref self: WorldStorage, ref combat: CombatState) {
        assert(combat.phase == Phase::Reveal, 'Not in reveal phase');

        let combatants_span = self.get_combatants(combat.id).span();
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
