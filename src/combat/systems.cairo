use core::{poseidon::{HashState}, hash::HashStateExTrait};
use starknet::{get_block_number, ContractAddress};

use dojo::{world::WorldStorage, model::{ModelStorage, Model}, event::EventStorage};
use blob_arena::{
    attacks::{Attack, AttackStorage, results::{AttackOutcomes, AttackResult}},
    combat::{
        CombatStorage, AttackCooledDown, components::{CombatState, Phase, PhaseTrait, run_effects},
    },
    combatants::{CombatantState, CombatantStateTrait, CombatantTrait, CombatantStorage},
    commitments::Commitment, utils::SeedProbability, hash::UpdateHashToU128, constants::NZ_100,
};

use crate::erc721::ERC721Token;

#[generate_trait]
impl CombatImpl of CombatTrait {
    fn assert_commit_phase(self: @WorldStorage, id: felt252) {
        self.get_combat_phase(id).assert_commit();
    }
    fn assert_reveal_phase(self: @WorldStorage, id: felt252) {
        self.get_combat_phase(id).assert_reveal();
    }
    fn assert_created_phase(self: @WorldStorage, id: felt252) {
        self.get_combat_phase(id).assert_created();
    }
    fn assert_combat_running(self: @WorldStorage, id: felt252) {
        self.get_combat_phase(id).assert_running();
    }
    fn assert_combat_none(self: @WorldStorage, id: felt252) {
        self.get_combat_phase(id).assert_none();
    }
    fn next_round(ref self: WorldStorage, mut state: CombatState, combatants: Span<felt252>) {
        state.round += 1;
        state.phase = Phase::Commit;
        self.set_combat_state(state);
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
    fn end_combat(ref self: WorldStorage, ref state: CombatState, winner: felt252) {
        self.set_combat_phase(state.id, Phase::Ended(winner));
    }
    fn get_attacker_attack_speed(
        self: @WorldStorage, state: @CombatantState, attack: @Attack,
    ) -> u8 {
        *state.stats.dexterity + *attack.speed
    }

    fn check_attack_has_cooled_down(
        self: @WorldStorage, combatant_id: felt252, attack_id: felt252, round: u32,
    ) -> AttackCooledDown {
        let cooldown = self.get_attack_cooldown(attack_id);
        if cooldown.is_zero() {
            AttackCooledDown::True(false)
        } else {
            let last_used = self.get_attack_last_used(combatant_id, attack_id);
            if last_used.is_zero() || ((cooldown.into() + last_used) < round) {
                AttackCooledDown::True(true)
            } else {
                AttackCooledDown::False
            }
        }
    }
    fn run_attack_cooldown(
        ref self: WorldStorage, combatant_id: felt252, attack_id: felt252, round: u32,
    ) -> bool {
        match self.check_attack_has_cooled_down(combatant_id, attack_id, round) {
            AttackCooledDown::True(has_cooldown) => {
                if has_cooldown {
                    self.set_attack_last_used(combatant_id, attack_id, round);
                };
                true
            },
            AttackCooledDown::False => false,
        }
    }
    fn run_attack_check(
        ref self: WorldStorage, combatant_id: felt252, attack_id: felt252, round: u32,
    ) -> bool {
        self.check_attack_available(combatant_id, attack_id)
            && self.run_attack_cooldown(combatant_id, attack_id, round)
    }

    fn get_speed(self: @(CombatantState, Attack)) -> u8 {
        let (state, attack) = self;
        *state.stats.dexterity + *attack.speed
    }

    fn run_attack(
        ref self: WorldStorage,
        ref attacker_state: CombatantState,
        ref defender_state: CombatantState,
        attack_id: felt252,
        round: u32,
        checked: bool,
        hash_state: HashState,
    ) -> AttackResult {
        let hash_state = hash_state.update_with(attacker_state.id);
        let mut seed = hash_state.to_u128();
        let result = if attack_id.is_zero()
            || !(checked || self.run_attack_check(attacker_state.id, attack_id, round)) {
            AttackOutcomes::Failed
        } else if attacker_state.run_stun(ref seed) {
            AttackOutcomes::Stunned
        } else if seed.get_outcome(NZ_100, self.get_attack_accuracy(attack_id)) {
            AttackOutcomes::Hit(
                run_effects(
                    ref attacker_state,
                    ref defender_state,
                    self.get_attack_hit_effects(attack_id),
                    hash_state,
                ),
            )
        } else {
            AttackOutcomes::Miss(
                run_effects(
                    ref attacker_state,
                    ref defender_state,
                    self.get_attack_miss_effects(attack_id),
                    hash_state,
                ),
            )
        };
        AttackResult {
            combatant_id: attacker_state.id, attack: attack_id, target: defender_state.id, result,
        }
    }

    fn increase_consecutive_wins(
        ref self: WorldStorage, player: ContractAddress, token: ERC721Token, combatant_id: felt252,
    ) {
        let mut update = false;
        let mut player_model = self.get_combat_consecutive_wins(player);
        let token_model = self.get_combat_consecutive_token_wins(player, token);

        let token_current = token_model.current + 1;
        player_model.current += 1;

        if token_current > token_model.max {
            self.set_combat_consecutive_token_wins(player, token, token_current);
            if token_current > player_model.token_max {
                player_model.token_max = token_current;
            }
            update = true;
        } else {
            self.set_combat_current_consecutive_token_wins(player, token, token_current);
        };

        if player_model.current > player_model.max {
            player_model.max = player_model.current;
            update = true;
        };

        if update {
            self.set_combat_consecutive_wins(player_model);
        } else {
            self.set_combat_current_consecutive_wins(player, player_model.current);
        };
    }

    fn reset_consecutive_wins(ref self: WorldStorage, player: ContractAddress, token: ERC721Token) {
        self.reset_combat_current_consecutive_wins(player);
        self.reset_combat_current_consecutive_token_wins(player, token);
    }
}
