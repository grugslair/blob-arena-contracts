use ba_loadout::attack::{
    AbilityAffect, Affect, Effect, IAttackDispatcher, IAttackDispatcherTrait, Target,
};
use ba_utils::{SeedProbability, UpdateHashToU128, felt252_to_u128};
use core::hash::{HashStateExTrait, HashStateTrait};
use core::num::traits::Zero;
use core::poseidon::HashState;
use sai_core_utils::BoolIntoBinary;
use starknet::storage::{Mutable, PendingStoragePath};
use crate::calculations::{damage_calculation, did_critical};
use crate::result::{AffectResult, AttackOutcomes, AttackResult, DamageResult, EffectResult};
use crate::{CombatantState, CombatantStateTrait};
#[derive(Copy, Drop, PartialEq, Introspect, Serde, Default)]
pub enum CombatProgress {
    #[default]
    Active,
    Ended: bool,
}

pub type StatePath = PendingStoragePath<Mutable<CombatantState>>;
pub type RoundPtr = PendingStoragePath<Mutable<u32>>;

fn run_effect(
    ref attacker_state: CombatantState,
    ref defender_state: CombatantState,
    effect: Effect,
    move_n: u32,
    hash_state: HashState,
) -> EffectResult {
    let result = match effect.affect {
        Affect::Abilities(abilities_effect) => {
            AffectResult::Abilities(
                match effect.target {
                    Target::Player => { attacker_state.apply_buffs(abilities_effect) },
                    Target::Opponent => { defender_state.apply_buffs(abilities_effect) },
                },
            )
        },
        Affect::Ability(AbilityAffect {
            ability, amount,
        }) => {
            let change = match effect.target {
                Target::Player => { attacker_state.apply_buff(ability, amount) },
                Target::Opponent => { defender_state.apply_buff(ability, amount) },
            };
            AffectResult::Ability(AbilityAffect { ability, amount: change })
        },
        Affect::Damage(damage) => {
            let mut seed = hash_state.update_to_u128(move_n);

            let critical = did_critical(damage.critical, attacker_state.abilities.luck, ref seed);

            let damage = damage_calculation(
                damage.power, attacker_state.abilities.strength, critical,
            );
            match effect.target {
                Target::Player => { attacker_state.modify_health(-(damage.try_into().unwrap())) },
                Target::Opponent => { defender_state.modify_health(-(damage.try_into().unwrap())) },
            }
            AffectResult::Damage(DamageResult { critical, damage })
        },
        Affect::Stun(stun) => {
            match effect.target {
                Target::Player => { attacker_state.apply_stun(stun) },
                Target::Opponent => { defender_state.apply_stun(stun) },
            }
            AffectResult::Stun(stun)
        },
        Affect::Health(health) => {
            AffectResult::Health(
                match effect.target {
                    Target::Player => { attacker_state.modify_health(health) },
                    Target::Opponent => { defender_state.modify_health(health) },
                },
            )
        },
    };
    EffectResult { target: effect.target, affect: result }
}


pub fn run_effects(
    ref attacker_state: CombatantState,
    ref defender_state: CombatantState,
    effects: Array<Effect>,
    hash_state: HashState,
) -> Array<EffectResult> {
    let mut results: Array<EffectResult> = ArrayTrait::new();
    for (n, effect) in effects.into_iter().enumerate() {
        results.append(run_effect(ref attacker_state, ref defender_state, effect, n, hash_state));
    }
    results
}

pub fn check_combat_active(state_1: @CombatantState, state_2: @CombatantState) -> CombatProgress {
    if state_1.health.is_non_zero() && state_2.health.is_non_zero() {
        CombatProgress::Active
    } else {
        CombatProgress::Ended(state_1.health.is_non_zero())
    }
}


fn get_switch_order(
    state_1: @CombatantState,
    state_2: @CombatantState,
    attacks: IAttackDispatcher,
    attack_1: felt252,
    attack_2: felt252,
    randomness: felt252,
) -> bool {
    let speed_1 = attacks.speed(attack_1) + *(state_1.abilities.dexterity);
    let speed_2 = attacks.speed(attack_2) + *(state_2.abilities.dexterity);
    if speed_1 == speed_2 {
        felt252_to_u128(randomness) % 2 == 0
    } else {
        speed_1 < speed_2
    }
}


#[derive(Drop, Serde)]
pub struct Round {
    pub round: u32,
    pub player_states: [CombatantState; 2],
    pub switch_order: bool,
    pub outcomes: Array<AttackResult>,
    pub progress: CombatProgress,
}

pub fn run_round(
    player_1_state: CombatantState,
    player_2_state: CombatantState,
    attacks: IAttackDispatcher,
    p1_attack: felt252,
    p2_attack: felt252,
    round: u32,
    randomness: felt252,
) -> Round {
    let hash_state = Default::default().update_with(randomness);
    let switch_order = get_switch_order(
        @player_1_state, @player_2_state, attacks, p1_attack, p2_attack, randomness,
    );
    let (mut state_1, mut state_2, attack_1, attack_2) = match switch_order {
        false => (player_1_state, player_2_state, p1_attack, p2_attack),
        true => (player_2_state, player_1_state, p2_attack, p1_attack),
    };

    let mut progress = CombatProgress::Active;
    let outcome = run_attack(
        ref state_1, ref state_2, attacks, attack_1, round, hash_state.update('1'),
    );
    let mut outcomes = array![AttackResult { attack: attack_1, result: outcome }];
    progress = check_combat_phase(@state_1, @state_2, switch_order, true);
    if progress == CombatProgress::Active {
        let outcome = run_attack(
            ref state_2, ref state_1, attacks, attack_2, round, hash_state.update('2'),
        );
        outcomes.append(AttackResult { attack: attack_2, result: outcome });
        progress = check_combat_phase(@state_1, @state_2, switch_order, false);
    }
    let (player_1_state, player_2_state) = match switch_order {
        false => (state_1, state_2),
        true => (state_2, state_1),
    };
    Round {
        round, player_states: [player_1_state, player_2_state], switch_order, outcomes, progress,
    }
}


fn run_attack(
    ref attacker_state: CombatantState,
    ref defender_state: CombatantState,
    attacks: IAttackDispatcher,
    attack_id: felt252,
    round: u32,
    hash_state: HashState,
) -> AttackOutcomes {
    let mut seed = hash_state.to_u128();
    if attack_id.is_zero() {
        AttackOutcomes::Failed
    } else if attacker_state.run_stun(ref seed) {
        AttackOutcomes::Stunned
    } else if seed.get_outcome(100, attacks.accuracy(attack_id)) {
        AttackOutcomes::Hit(
            run_effects(ref attacker_state, ref defender_state, attacks.hit(attack_id), hash_state),
        )
    } else {
        AttackOutcomes::Miss(
            run_effects(
                ref attacker_state, ref defender_state, attacks.miss(attack_id), hash_state,
            ),
        )
    }
}

fn check_combat_phase(
    state_1: @CombatantState, state_2: @CombatantState, switched: bool, advantage: bool,
) -> CombatProgress {
    let (player_1, player_2) = match switched {
        false => (state_1, state_2),
        true => (state_2, state_1),
    };
    if player_1.health.is_non_zero() && player_2.health.is_non_zero() {
        CombatProgress::Active
    } else if player_1.health.is_non_zero() {
        CombatProgress::Ended(true)
    } else if player_2.health.is_non_zero() {
        CombatProgress::Ended(false)
    } else {
        CombatProgress::Ended(switched != advantage)
    }
}
