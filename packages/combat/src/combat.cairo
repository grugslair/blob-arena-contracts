use ba_loadout::attack::{Affect, Effect, IAttackDispatcher, IAttackDispatcherTrait, Target};
use ba_utils::{Randomness, RandomnessTrait};
use core::num::traits::Zero;
use sai_core_utils::BoolIntoBinary;
use crate::result::{AffectResult, AttackOutcomes, EffectResult};
use crate::{CombatantState, CombatantStateTrait};


#[derive(Copy, Drop, PartialEq, Introspect, Serde, Default)]
pub enum CombatProgress {
    #[default]
    Active,
    Ended: Player,
}

impl BoolIntoPLayer of Into<bool, Player> {
    fn into(self: bool) -> Player {
        match self {
            false => Player::Player1,
            true => Player::Player2,
        }
    }
}

#[derive(Copy, Drop, Serde, PartialEq, Default, Introspect)]
pub enum Player {
    #[default]
    Player1,
    Player2,
}

fn run_effect(
    ref attacker_state: CombatantState,
    ref defender_state: CombatantState,
    effect: Effect,
    move_n: u32,
    ref randomness: Randomness,
) -> EffectResult {
    let result = match effect.affect {
        Affect::Strength(amount) => {
            match effect.target {
                Target::Player => attacker_state.apply_strength_buff(amount),
                Target::Opponent => defender_state.apply_strength_buff(amount),
            }
            AffectResult::Applied
        },
        Affect::Vitality(amount) => {
            match effect.target {
                Target::Player => attacker_state.apply_vitality_buff(amount),
                Target::Opponent => defender_state.apply_vitality_buff(amount),
            }
            AffectResult::Applied
        },
        Affect::Dexterity(amount) => {
            match effect.target {
                Target::Player => attacker_state.apply_dexterity_buff(amount),
                Target::Opponent => defender_state.apply_dexterity_buff(amount),
            }
            AffectResult::Applied
        },
        Affect::Luck(amount) => {
            match effect.target {
                Target::Player => attacker_state.apply_luck_buff(amount),
                Target::Opponent => defender_state.apply_luck_buff(amount),
            }
            AffectResult::Applied
        },
        Affect::Damage(damage) => {
            let d_result = match effect.target {
                Target::Player => attacker_state
                    .apply_damage(damage, @attacker_state.abilities, ref randomness),
                Target::Opponent => defender_state
                    .apply_damage(damage, @attacker_state.abilities, ref randomness),
            };
            AffectResult::Damage(d_result)
        },
        Affect::Stun(stun) => {
            match effect.target {
                Target::Player => { attacker_state.apply_stun(stun) },
                Target::Opponent => { defender_state.apply_stun(stun) },
            }
            AffectResult::Applied
        },
        Affect::Health(health) => {
            match effect.target {
                Target::Player => { attacker_state.modify_health(health) },
                Target::Opponent => { defender_state.modify_health(health) },
            }
            AffectResult::Applied
        },
        Affect::Block(block) => {
            match effect.target {
                Target::Player => { attacker_state.apply_block(block) },
                Target::Opponent => { defender_state.apply_block(block) },
            }
            AffectResult::Applied
        },
    };
    EffectResult { target: effect.target, affect: result }
}


pub fn run_effects(
    ref attacker_state: CombatantState,
    ref defender_state: CombatantState,
    effects: Array<Effect>,
    ref randomness: Randomness,
) -> Array<EffectResult> {
    let mut results: Array<EffectResult> = ArrayTrait::new();
    for (n, effect) in effects.into_iter().enumerate() {
        results
            .append(run_effect(ref attacker_state, ref defender_state, effect, n, ref randomness));
    }
    results
}


fn get_switch_order(
    state_1: @CombatantState,
    state_2: @CombatantState,
    attacks: IAttackDispatcher,
    attack_1: felt252,
    attack_2: felt252,
    ref randomness: Randomness,
) -> bool {
    let speed_1 = attacks.speed(attack_1) + *(state_1.abilities.dexterity);
    let speed_2 = attacks.speed(attack_2) + *(state_2.abilities.dexterity);
    if speed_1 == speed_2 {
        randomness.get_bool()
    } else {
        speed_1 < speed_2
    }
}


#[derive(Drop, Serde)]
pub struct Round {
    pub round: u32,
    pub states: [CombatantState; 2],
    pub attacks: [felt252; 2],
    pub first: Player,
    pub outcomes: Array<AttackOutcomes>,
    pub progress: CombatProgress,
}

pub fn run_round(
    p1_state: CombatantState,
    p2_state: CombatantState,
    attacks: IAttackDispatcher,
    p1_attack: felt252,
    p2_attack: felt252,
    round: u32,
    ref randomness: Randomness,
) -> Round {
    let switch_order = get_switch_order(
        @p1_state, @p2_state, attacks, p1_attack, p2_attack, ref randomness,
    );
    let (mut state_1, mut state_2, attack_1, attack_2) = match switch_order {
        false => (p1_state, p2_state, p1_attack, p2_attack),
        true => (p2_state, p1_state, p2_attack, p1_attack),
    };

    let mut progress = CombatProgress::Active;
    let outcome = run_attack(ref state_1, ref state_2, attacks, attack_1, round, ref randomness);
    let mut outcomes = array![outcome];
    progress = check_combat_phase(@state_1, @state_2, switch_order, true);
    if progress == CombatProgress::Active {
        let outcome = run_attack(
            ref state_2, ref state_1, attacks, attack_2, round, ref randomness,
        );
        outcomes.append(outcome);
        progress = check_combat_phase(@state_1, @state_2, switch_order, false);
    }
    let (states, attacks) = match switch_order {
        false => ([state_1, state_2], [p1_attack, p2_attack]),
        true => ([state_2, state_1], [p2_attack, p1_attack]),
    };
    Round { round, attacks, first: switch_order.into(), states, outcomes, progress }
}


fn run_attack(
    ref attacker_state: CombatantState,
    ref defender_state: CombatantState,
    attacks: IAttackDispatcher,
    attack_id: felt252,
    round: u32,
    ref randomness: Randomness,
) -> AttackOutcomes {
    if attack_id.is_zero() {
        AttackOutcomes::Failed
    } else if attacker_state.run_stun(ref randomness) {
        AttackOutcomes::Stunned
    } else if randomness.get(100) < attacks.chance(attack_id) {
        let result = run_effects(
            ref attacker_state, ref defender_state, attacks.success(attack_id), ref randomness,
        );
        AttackOutcomes::Success(result)
    } else {
        let result = run_effects(
            ref attacker_state, ref defender_state, attacks.fail(attack_id), ref randomness,
        );
        AttackOutcomes::Fail(result)
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
        CombatProgress::Ended(Player::Player1)
    } else if player_2.health.is_non_zero() {
        CombatProgress::Ended(Player::Player2)
    } else {
        CombatProgress::Ended((switched == advantage).into())
    }
}
