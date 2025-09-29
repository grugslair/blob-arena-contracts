use ba_loadout::attack::effect::Duration;
use ba_loadout::attack::{Affect, Effect, IAttackDispatcher, IAttackDispatcherTrait, Target};
use ba_utils::{Randomness, RandomnessTrait};
use core::num::traits::Zero;
use sai_core_utils::BoolIntoBinary;
use crate::result::{AffectResult, AttackResult, EffectResult, RoundEffectResult};
use crate::round_effect::{RoundEffect, RoundEffects, RoundEffectsTrait};
use crate::{CombatantState, CombatantStateTrait};

#[derive(Copy, Drop, PartialEq, Introspect, Serde, Default)]
pub enum CombatProgress {
    #[default]
    Active,
    Ended: Player,
}


#[derive(Destruct)]
pub struct Combat {
    pub combat_id: felt252,
    pub first: Option<Player>,
    pub state_1: CombatantState,
    pub state_2: CombatantState,
    pub round_effects: RoundEffects,
    pub round: u32,
    pub progress: CombatProgress,
    pub randomness: Randomness,
    pub attacks: IAttackDispatcher,
    pub attack_results: Array<AttackResult>,
    pub round_effect_results: Array<RoundEffectResult>,
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

#[generate_trait]
impl PlayerImpl of PlayerTrait {
    fn target(self: Player, target: Target) -> Player {
        match target {
            Target::Attacker => self,
            Target::Defender => !self,
        }
    }
}

impl NotPlayer of Not<Player> {
    fn not(a: Player) -> Player {
        match a {
            Player::Player1 => Player::Player2,
            Player::Player2 => Player::Player1,
        }
    }
}

#[generate_trait]
impl CombatImpl of CombatTrait {
    fn new(
        combat_id: felt252,
        round: u32,
        state_1: CombatantState,
        state_2: CombatantState,
        randomness: Randomness,
        attacks: IAttackDispatcher,
    ) -> Combat {
        Combat {
            combat_id,
            state_1,
            state_2,
            first: None,
            round_effects: RoundEffectsTrait::new(combat_id, round),
            round,
            progress: CombatProgress::Active,
            randomness,
            attacks,
            attack_results: Default::default(),
            round_effect_results: Default::default(),
        }
    }

    fn apply_affect(
        ref self: Combat, source: Player, target: Player, affect: Affect,
    ) -> EffectResult {
        let attacker_state = self.get_attacker_state(source);
        let affect = match target {
            Player::Player1 => self
                .state_1
                .apply_affect(affect, attacker_state, ref self.randomness),
            Player::Player2 => self
                .state_2
                .apply_affect(affect, attacker_state, ref self.randomness),
        };
        EffectResult { target, affect }
    }

    fn get_attacker_state(self: @Combat, player: Player) -> @CombatantState {
        match player {
            Player::Player1 => self.state_1,
            Player::Player2 => self.state_2,
        }
    }

    fn apply_round_effect(
        ref self: Combat, source: Player, target: Player, affect: Affect, round: u32,
    ) {
        self.round_effects.add_effect(RoundEffect { source, target, affect }, round)
    }

    fn apply_infinite_effect(ref self: Combat, source: Player, target: Player, affect: Affect) {
        self.round_effects.add_infinite_effect(RoundEffect { source, target, affect })
    }

    fn apply_effect(ref self: Combat, source: Player, effect: Effect) -> EffectResult {
        let Effect { duration, target, affect } = effect;
        let target = source.target(target);
        match duration {
            Duration::Instant => self.apply_affect(source, target, affect),
            Duration::Round(round) => {
                self.apply_round_effect(source, target, affect, round);
                EffectResult { target, affect: AffectResult::Applied }
            },
            Duration::Rounds(count) => {
                for round in 1..(count + 1) {
                    self.apply_round_effect(source, target, affect, round);
                }
                EffectResult { target, affect: AffectResult::Applied }
            },
            Duration::Infinite => {
                self.apply_infinite_effect(source, target, affect);
                EffectResult { target, affect: AffectResult::Applied }
            },
        }
    }

    fn apply_effects(
        ref self: Combat, attacker: Player, effects: Array<Effect>,
    ) -> Array<EffectResult> {
        let mut results: Array<EffectResult> = ArrayTrait::new();
        for effect in effects {
            results.append(self.apply_effect(attacker, effect));
        }
        results
    }

    fn run_stun(ref self: Combat, player: Player) -> bool {
        match player {
            Player::Player1 => self.state_1.run_stun(ref self.randomness),
            Player::Player2 => self.state_2.run_stun(ref self.randomness),
        }
    }

    fn run_attack(ref self: Combat, source: Player, attack_id: felt252) {
        let result = if attack_id.is_zero() {
            AttackResult::Failed
        } else if self.run_stun(source) {
            AttackResult::Stunned
        } else if self.randomness.get(100) < self.attacks.chance(attack_id) {
            AttackResult::Success(self.apply_effects(source, self.attacks.success(attack_id)))
        } else {
            AttackResult::Fail(self.apply_effects(source, self.attacks.fail(attack_id)))
        };
        self.attack_results.append(result);
        self.check_progress(!source);
    }

    fn check_progress(ref self: Combat, advantage: Player) {
        self
            .progress =
                if self.state_1.health.is_non_zero() && self.state_2.health.is_non_zero() {
                    CombatProgress::Active
                } else if self.state_1.health.is_non_zero() {
                    CombatProgress::Ended(Player::Player1)
                } else if self.state_2.health.is_non_zero() {
                    CombatProgress::Ended(Player::Player2)
                } else {
                    CombatProgress::Ended(advantage) // Both dead, Player 1 wins by default
                };
    }

    fn get_first_player(ref self: Combat, attacks: [felt252; 2]) {
        let [attack_1, attack_2] = attacks;
        let speed_1 = self.attacks.speed(attack_1) + (self.state_1.dexterity).into();
        let speed_2 = self.attacks.speed(attack_2) + (self.state_2.dexterity).into();
        self
            .first =
                Some(
                    if speed_1 == speed_2 {
                        self.randomness.get_bool()
                    } else {
                        speed_1 < speed_2
                    }
                        .into(),
                );
    }

    fn run_round_effects(ref self: Combat) -> CombatProgress {
        let mut phase: CombatProgress = Default::default();
        for effect in (@self.round_effects).into_iter() {
            self.apply_affect(effect.source, effect.target, effect.affect);
            self.check_progress(!effect.source);
            if self.progress != CombatProgress::Active {
                return phase;
            }
        }
        phase
    }

    fn states(self: @Combat) -> [CombatantState; 2] {
        [*self.state_1, *self.state_2]
    }


    fn to_round(self: Combat, attacks: [felt252; 2]) -> Round {
        Round {
            round: self.round,
            attacks,
            first: self.first,
            states: [self.state_1, self.state_2],
            round_effects_results: self.round_effect_results,
            attack_results: self.attack_results,
            progress: self.progress,
        }
    }

    fn run_round(ref self: Combat, attacks: [felt252; 2], ref randomness: Randomness) {
        self.run_round_effects();
        if self.progress == CombatProgress::Active {
            self.get_first_player(attacks);
            let first = self.first.unwrap();
            let [attack_1, attack_2] = match self.first.unwrap() {
                Player::Player1 => attacks,
                Player::Player2 => {
                    let [a2, a1] = attacks;
                    [a1, a2]
                },
            };
            self.run_attack(first, attack_1);
            if self.progress == CombatProgress::Active {
                self.run_attack(!first, attack_2);
            }
        }
    }
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
    pub first: Option<Player>,
    pub round_effects_results: Array<RoundEffectResult>,
    pub attack_results: Array<AttackResult>,
    pub progress: CombatProgress,
}

