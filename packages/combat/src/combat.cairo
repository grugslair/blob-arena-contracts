use ba_loadout::attack::effect::Duration;
use ba_loadout::attack::{Effect, IAttackDispatcher, IAttackDispatcherTrait, Target};
use ba_utils::{Randomness, RandomnessTrait};
use core::num::traits::Zero;
use sai_core_utils::BoolIntoBinary;
use crate::result::{AttackOutcomes, EffectResult, InstantAffectResult};
use crate::round_effect::RoundEffects;
use crate::{CombatantState, CombatantStateTrait};

#[derive(Copy, Drop, PartialEq, Introspect, Serde, Default)]
pub enum CombatProgress {
    #[default]
    Active,
    Ended: Player,
}


#[derive(PanicDestruct)]
pub struct Combat {
    pub combat_id: felt252,
    pub state_1: CombatantState,
    pub state_2: CombatantState,
    pub round_effects: RoundEffects,
    pub round: u32,
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

impl NotPlayer of Not<Player> {
    fn not(a: Player) -> Player {
        match a {
            Player::Player1 => Player::Player2,
            Player::Player2 => Player::Player1,
        }
    }
}

fn run_effect(
    ref attacker_state: CombatantState,
    ref defender_state: CombatantState,
    player: Player,
    effect: Effect,
    ref round_effects: RoundEffects,
    ref randomness: Randomness,
) -> EffectResult {
    match effect.duration {
        Duration::Instant => {
            let mut result = match effect.target {
                Target::None => InstantAffectResult::None,
                Target::Attacker => attacker_state
                    .apply_affect(effect.affect, @attacker_state, ref randomness),
                Target::Defender => defender_state
                    .apply_affect(effect.affect, @attacker_state, ref randomness),
            };
        },
        Duration::Round(round) => {},
        Duration::Rounds(count) => {},
        Duration::Infinite => {},
    }

    EffectResult { target: effect.target, affect: result }
}


pub fn run_effects(
    ref attacker_state: CombatantState,
    ref defender_state: CombatantState,
    player: Player,
    effects: Array<Effect>,
    ref round_effects: RoundEffects,
    ref randomness: Randomness,
) -> Array<EffectResult> {
    let mut results: Array<EffectResult> = ArrayTrait::new();
    for effect in effects {
        results.append(run_effect(ref attacker_state, ref defender_state, effect, ref randomness));
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
    let speed_1 = attacks.speed(attack_1) + (*state_1.dexterity).into();
    let speed_2 = attacks.speed(attack_2) + (*state_2.dexterity).into();
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
    ref p1_state: CombatantState,
    ref p2_state: CombatantState,
    attacks: IAttackDispatcher,
    p1_attack: felt252,
    p2_attack: felt252,
    round: u32,
    ref round_effects: RoundEffects,
    ref randomness: Randomness,
) -> Round {
    let mut progress = run_round_effects(
        ref p1_state, ref p2_state, ref round_effects, ref randomness,
    );
    if progress != CombatProgress::Active {
        return Round {
            round,
            attacks: [p1_attack, p2_attack],
            first: Player::Player1,
            states: [p1_state, p2_state],
            outcomes: ArrayTrait::new(),
            progress,
        };
    }

    let switch_order = get_switch_order(
        @p1_state, @p2_state, attacks, p1_attack, p2_attack, ref randomness,
    );
    let (mut state_1, mut state_2, attack_1, attack_2) = match switch_order {
        false => (p1_state, p2_state, p1_attack, p2_attack),
        true => (p2_state, p1_state, p2_attack, p1_attack),
    };

    let outcome = run_attack(
        ref state_1, ref state_2, attacks, attack_1, round, ref round_effects, ref randomness,
    );
    let mut outcomes = array![outcome];
    progress = check_combat_phase(@state_1, @state_2, switch_order, true);
    if progress == CombatProgress::Active {
        let outcome = run_attack(
            ref state_2, ref state_1, attacks, attack_2, round, ref round_effects, ref randomness,
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

fn run_round_effects(
    ref p1_state: CombatantState,
    ref p2_state: CombatantState,
    ref round_effects: RoundEffects,
    ref randomness: Randomness,
) -> CombatProgress {
    let mut phase: CombatProgress = Default::default();
    for effect in (@round_effects).into_iter() {
        let (attacker, switch) = match effect.attacker {
            Player::Player1 => (@p1_state, false),
            Player::Player2 => (@p2_state, true),
        };
        match effect.defender {
            Player::Player1 => { p1_state.apply_affect(effect.affect, attacker, ref randomness); },
            Player::Player2 => { p2_state.apply_affect(effect.affect, attacker, ref randomness); },
        }
        phase = check_combat_phase(@p1_state, @p2_state, switch, true);
        if phase != CombatProgress::Active {
            return phase;
        }
    }
    phase
}


fn run_attack(
    ref attacker_state: CombatantState,
    ref defender_state: CombatantState,
    attacks: IAttackDispatcher,
    attack_id: felt252,
    round: u32,
    ref round_effects: RoundEffects,
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

