use core::{poseidon::{HashState,}, hash::HashStateExTrait};
use starknet::get_block_number;

use dojo::{world::WorldStorage, model::{ModelStorage, Model}, event::EventStorage};
use blob_arena::{
    attacks::{
        Attack, AttackTrait, systems::{PlannedAttackTrait, PlannedAttack, AvailableAttackTrait},
        results::{AttackOutcomes, AttackResult}
    },
    combat::components::{CombatState, Phase, PhaseTrait, run_effects},
    combatants::{CombatantState, CombatantStateTrait, CombatantTrait}, commitments::Commitment,
    salts::{Salts}, utils::SeedProbability, hash::UpdateHashToU128, constants::NZ_100,
};


#[generate_trait]
impl CombatImpl of CombatTrait {
    fn set_combat_phase(ref self: WorldStorage, id: felt252, phase: Phase) {
        self.write_member(Model::<CombatState>::ptr_from_keys(id), selector!("phase"), phase);
    }
    fn get_combat_state(self: @WorldStorage, id: felt252) -> CombatState {
        self.read_model(id)
    }
    fn new_combat_state(ref self: WorldStorage, id: felt252) {
        self.write_model(@CombatState { id, phase: Phase::Commit, round: 1 });
    }
    fn get_combat_phase(self: @WorldStorage, id: felt252) -> Phase {
        self.get_combat_state(id).phase
    }
    fn get_running_combat_state(self: @WorldStorage, id: felt252) -> CombatState {
        let state = self.get_combat_state(id);
        state.phase.assert_running();
        state
    }
    fn next_round(ref self: WorldStorage, mut state: CombatState, combatants: Span<felt252>) {
        self.reset_salts(state.id);
        self.clear_commitments_with(combatants);
        self.clear_planned_attacks(combatants);
        state.round += 1;
        state.phase = Phase::Commit;
        self.write_model(@state);
    }
    fn get_combatants_mortality(self: Span<CombatantState>) -> (Array<felt252>, Array<felt252>) {
        let mut alive = ArrayTrait::<felt252>::new();
        let mut dead = ArrayTrait::<felt252>::new();
        for state in self {
            if (*state.health).is_non_zero() {
                alive.append(*state.id);
            } else {
                dead.append(*state.id);
            }
        };
        (alive, dead)
    }
    fn end_combat(ref self: WorldStorage, mut state: CombatState, winner: felt252) {
        state.phase = Phase::Ended(winner);
        self.write_model(@state);
    }
    fn get_attacker_attack_speed(
        self: @WorldStorage, state: @CombatantState, attack: @Attack
    ) -> u8 {
        *state.stats.dexterity + *attack.speed
    }
    fn run_attack_check(
        ref self: WorldStorage, combatant_id: felt252, attack_id: felt252, cooldown: u8, round: u32
    ) -> bool {
        let attack_available = self.get_available_attack(combatant_id, attack_id);
        if attack_available.check_attack_useable(cooldown, round) {
            if cooldown.is_non_zero() {
                self.set_attack_last_used(combatant_id, attack_id, round)
            }
            true
        } else {
            false
        }
    }

    fn get_state_and_attack(
        self: @WorldStorage, planned_attack: @PlannedAttack
    ) -> (CombatantState, Attack) {
        (
            self.get_combatant_state(*planned_attack.combatant),
            self.get_attack(*planned_attack.attack)
        )
    }

    fn get_states_and_attacks(
        self: @WorldStorage, planned_attacks: Span<PlannedAttack>
    ) -> Array<(CombatantState, Attack)> {
        let mut array = ArrayTrait::<(CombatantState, Attack)>::new();
        for planned_attack in planned_attacks {
            array.append(self.get_state_and_attack(planned_attack));
        };
        array
    }

    fn run_attack(
        ref self: WorldStorage,
        ref attacker_state: CombatantState,
        ref defender_state: CombatantState,
        attack: @Attack,
        round: u32,
        hash_state: HashState
    ) -> AttackResult {
        let hash_state = hash_state.update_with(attacker_state.id);
        let mut seed = hash_state.to_u128();

        let result = if !self
            .run_attack_check(attacker_state.id, *(attack.id), *(attack.cooldown), round) {
            AttackOutcomes::Failed
        } else if attacker_state.run_stun(ref seed) {
            AttackOutcomes::Stunned
        } else if seed.get_outcome(NZ_100, *(attack.accuracy)) {
            AttackOutcomes::Hit(
                run_effects(ref attacker_state, ref defender_state, *(attack.hit), hash_state)
            )
        } else {
            AttackOutcomes::Miss(
                run_effects(ref attacker_state, ref defender_state, *(attack.miss), hash_state)
            )
        };
        AttackResult {
            combatant_id: attacker_state.id, attack: *attack.id, target: defender_state.id, result
        }
    }
}
