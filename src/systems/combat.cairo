use core::{
    hash::HashStateTrait, poseidon::{PoseidonTrait, HashState},
    dict::{Felt252Dict, Felt252DictTrait}
};

// use alexandria_data_structures::array_ext::SpanTraitExt;
// use alexandria_data_structures::array_ext::ArrayTraitExt;
use cubit::f128::types::fixed::{FixedTrait, Fixed, HALF};

use core::integer::u128_safe_divmod;

use blob_arena::{
    core::{LimitSub, LimitAdd}, utils::{ToHash, felt252_to_u128},
    components::{
        combat::{Phase, AttackEffect, AttackHit},
        combatant::{CombatantState, CombatantStats, CombatantInfo, CombatantTrait},
        attack::{Attack, AttackTrait, AvailableAttack}, utils::{AB, ABT, ABTTrait}, stats::{Stats},
    },
    models::{AttackResult},
};
use dojo::{world::{IWorldDispatcher, IWorldDispatcherTrait}, model::Model};

const HUNDRED: felt252 = 1844674407370955161600;
const FIXED_255: u128 = 4703919738795935662080;
const HUNDREDTH: felt252 = 184467440737095516;
const THREE_TENTHS: felt252 = 5534023222112865484;
const NZ_255: NonZero<u128> = 255;
const NZ_100: NonZero<u128> = 100;

#[derive(Drop, Serde, Copy)]
struct PlannedAttack {
    combatant: u128,
    attack: Attack,
    target: u128,
}

fn apply_strength_modifier<T, +TryInto<Fixed, T>, +Into<u8, T>, +Zeroable<T>>(
    value: u8, strength: u8
) -> T {
    if value == 0 {
        return Zeroable::zero();
    };
    let strength_ratio: Fixed = (300_u16 - strength.into()).into()
        / (200_u16 + strength.into()).into();
    let value_float: Fixed = value.into() / FixedTrait::from_felt(HUNDRED);
    let new_value = (value_float.pow(strength_ratio) * Fixed { mag: FIXED_255, sign: false });
    if new_value.mag > FIXED_255 {
        255_u8.into()
    } else {
        new_value.try_into().unwrap()
    }
}

fn get_new_stun_chance(current_stun: u8, attack_stun: u8, strength: u8) -> u8 {
    let stun_chance = apply_strength_modifier(attack_stun, strength);
    let mut new_stun = current_stun.into()
        + stun_chance
        - (current_stun.into() * stun_chance / 255_u16);
    if new_stun > 255 {
        new_stun = 255;
    };
    new_stun.try_into().unwrap()
}

fn damage_calculation(attack: u8, damage: u8, critical: bool) -> u8 {
    if damage == 0 {
        return 0;
    };
    let mut calc_damage: u32 = ((damage.into() / FixedTrait::from_felt(HUNDRED))
        .pow(FixedTrait::from_felt(THREE_TENTHS))
        * (200_u8.into() + attack.into()))
        .try_into()
        .unwrap(); // max value 300
    calc_damage /= if critical {
        6
    } else {
        12
    };
    if calc_damage > 255 {
        calc_damage = 255;
    };
    calc_damage.try_into().unwrap()
}

fn did_hit(accuracy: u8, seed: u128) -> (u128, bool) {
    let (seed, value) = u128_safe_divmod(seed, NZ_100);
    (seed, value < accuracy.into())
}

#[generate_trait]
impl AttackerImpl of AttackerTrait {
    fn get_damage(self: CombatantStats, attack: Attack, critical: bool, seed: u128) -> u8 {
        //TODO: Implement damage calculation
        damage_calculation(self.attack, attack.damage, critical)
    }

    fn did_hit(self: CombatantStats, attack: Attack, seed: u128) -> (u128, bool) {
        did_hit(attack.accuracy, seed)
    }

    // random less than 255
    fn did_critical(self: CombatantStats, attack: Attack, seed: u128) -> (u128, bool) {
        let critical: u8 = apply_strength_modifier(attack.critical, self.strength);
        let (seed, value) = u128_safe_divmod(seed, NZ_255);
        (seed, value < critical.into())
    }


    fn is_stunned(self: CombatantState, seed: u128) -> (u128, bool) {
        let (seed, value) = u128_safe_divmod(seed, NZ_255);
        (seed, value < self.stun_chance.into())
    }

    fn run_stun(ref self: CombatantState, seed: u128) -> (u128, bool) {
        let (seed, stunned) = self.is_stunned(seed);
        self.stun_chance = 0;
        (seed, stunned)
    }
}

#[generate_trait]
impl CombatWorldImp of CombatWorldTraits {
    fn run_attack_check(
        self: IWorldDispatcher, combatant_id: u128, attack: Attack, round: u32
    ) -> bool {
        let attack_available = self.get_available_attack(combatant_id, attack.id);
        if !attack_available.available {
            false
        } else {
            if attack.cooldown == 0 {
                return true;
            }
            let last_used = attack_available.last_used;
            if last_used.is_non_zero() && (attack.cooldown.into() + last_used) > round {
                return false;
            };
            self.set_available_attack(combatant_id, attack.id, round);
            true
        }
    }
    fn emit_attack_event(
        self: IWorldDispatcher,
        combatant_id: u128,
        round: u32,
        attack_id: u128,
        target: u128,
        effect: AttackEffect
    ) {
        let (effect, damage, stun, critical,) = match effect {
            AttackEffect::Failed => (0, 0, 0, false),
            AttackEffect::Stunned => (1, 0, 0, false),
            AttackEffect::Miss => (2, 0, 0, false),
            AttackEffect::Hit(affect) => (3, affect.damage, affect.stun, affect.critical),
        };
        AttackResult { combatant_id, round, attack_id, target, effect, damage, stun, critical, }
            .set(self);
        // AttackResult { combatant_id, round, attack_id, target, effect }.set(self);
    // emit!(self, AttackResult { combatant_id, round, attack_id, target, effect });
    }

    fn emit_heal_event(
        self: IWorldDispatcher,
        combatant_id: u128,
        round: u32,
        heal: u8
    ) {
        HealResult { combatant_id, round, heal }.set(self);
    }

    fn run_attack(
        self: IWorldDispatcher,
        attacker_stats: CombatantStats,
        mut attacker_state: CombatantState,
        mut defender_state: CombatantState,
        attack: Attack,
        round: u32,
        hash: HashState
    ) -> (CombatantState, CombatantState) {
        let seed = felt252_to_u128(hash.to_hash(attacker_stats.id));
        let (seed, stunned) = attacker_state.run_stun(seed);
        let (seed, hit) = attacker_stats.did_hit(attack, seed);
        if attack.name == "Heal" {
            attacker_state.health.add(attack.heal);
            self.emit_heal_event(attacker_stats.id, round, attack.heal);
        }
        let effect = if !self.run_attack_check(attacker_stats.id, attack, round) {
            AttackEffect::Failed
        } else if stunned {
            AttackEffect::Stunned
        } else if hit {
            let (seed, critical) = attacker_stats.did_critical(attack, seed);
            let damage = attacker_stats.get_damage(attack, critical, seed);

            defender_state.health.subeq(damage);
            if attack.stun > 0 {
                defender_state
                    .stun_chance =
                        get_new_stun_chance(
                            defender_state.stun_chance, attack.stun, attacker_stats.strength
                        );
            };
            AttackEffect::Hit(AttackHit { damage, stun: attack.stun, critical })
        } else {
            AttackEffect::Miss
        };
        self.emit_attack_event(attacker_stats.id, round, attack.id, defender_state.id, effect);

        (attacker_state, defender_state)
    }
}

