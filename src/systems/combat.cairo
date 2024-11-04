use core::{
    hash::{HashStateTrait, HashStateExTrait}, poseidon::{PoseidonTrait, HashState},
    {integer::u128_safe_divmod, cmp::min}
};

// use alexandria_data_structures::array_ext::SpanTraitExt;
// use alexandria_data_structures::array_ext::ArrayTraitExt;
use cubit::f128::types::fixed::{FixedTrait, Fixed, HALF};


use blob_arena::{
    core::{SaturatingInto, SaturatingSub}, utils::{UpdateHashToU128,},
    components::{
        combat::Phase,
        combatant::{CombatantState, CombatantInfo, CombatantTrait, CombatantStateTrait},
        attack::{Attack, AttackTrait, AvailableAttack}, utils::{AB, ABT, ABTTrait}, stats::{Stats},
    },
    models::{
        Effect, Affect, Damage, Target, Stat, AttackOutcomes, EffectResult, AffectResult,
        DamageResult, AttackResult
    },
};
use dojo::{world::{WorldStorage, ModelStorage}, model::Model};

fn apply_luck_modifier<T, +TryInto<Fixed, T>, +Into<u8, T>, +Zeroable<T>>(
    value: u8, luck: u8
) -> T {
    if value == 0 {
        return Zeroable::zero();
    };
    let luck_ratio: Fixed = (300_u16 - luck.into()).into() / (200_u16 + luck.into()).into();
    let value_float = value.into() / HUNDRED_FIXED;
    let new_value = (value_float.pow(luck_ratio) * FIXED_255);
    if new_value > FIXED_255 {
        255_u8.into()
    } else {
        new_value.try_into().unwrap()
    }
}

fn get_new_stun_chance(current_stun: u8, attack_stun: u8) -> u8 {
    (current_stun.into()
        + attack_stun.into()
        - (current_stun.into() * attack_stun.into() / 100_u16))
        .saturating_into()
}

// power * (1 + 0.004 * strength)
fn damage_calculation(move_power: u8, strength: u8, critical: bool) -> u8 {
    (move_power.into() * (100 + strength.into()) / if critical {
        125_u128
    } else {
        250_u128
    })
        .saturating_into()
}

fn did_critical(chance: u8, luck: u8, ref seed: u128) -> (u128, bool) {
    let critical: u8 = apply_luck_modifier(chance, luck);

    let (seed, value) = u128_safe_divmod(seed, NZ_255);
    (seed, value < critical.into())
}

#[generate_trait]
impl AttackerImpl of AttackerTrait {
    fn run_stun(ref self: CombatantState, ref seed: u128) -> bool {
        let stun_chance: u8 = apply_luck_modifier(self.stun_chance, 100 - self.stats.luck);
        self.stun_chance = 0;
        seed.get_outcome(NZ_255, stun_chance)
    }
}


fn apply_stun(ref self: CombatantState, stun: u8) {
    self.stun_chance = get_new_stun_chance(self.stun_chance, stun)
}


fn run_effect(
    ref attacker_state: CombatantState,
    ref defender_state: CombatantState,
    effect: @Effect,
    hash_state: HashState,
) -> (EffectResult, HashState) {
    let result = match effect.affect {
        Affect::Stats(stats_effect) => {
            match effect.target {
                Target::Player => { attacker_state.apply_buffs(stats_effect) },
                Target::Opponent => { defender_state.apply_buffs(stats_effect) },
            };
            AffectResult::Success
        },
        Affect::Stat(Stat { stat,
        amount }) => {
            match effect.target {
                Target::Player => { attacker_state.apply_buff(*stat, *amount) },
                Target::Opponent => { defender_state.apply_buff(*stat, *amount) },
            };
            AffectResult::Success
        },
        Affect::Damage(damage) => {
            let seed = hash_state.update_to_u128('salt');

            let (_seed, critical) = did_critical(
                *damage.critical, attacker_state.stats.luck, ref seed
            );

            let damage = damage_calculation(*damage.power, attacker_state.stats.strength, critical);
            match effect.target {
                Target::Player => { attacker_state.modify_health::<i16>(-(damage.into())) },
                Target::Opponent => { defender_state.modify_health::<i16>(-(damage.into())) },
            };
            AffectResult::Damage(DamageResult { critical, damage })
        },
        Affect::Stun(stun) => {
            match effect.target {
                Target::Player => { apply_stun(ref attacker_state, *stun) },
                Target::Opponent => { apply_stun(ref defender_state, *stun) },
            };
            AffectResult::Success
        },
        Affect::Health(health) => {
            match effect.target {
                Target::Player => { attacker_state.modify_health(*health) },
                Target::Opponent => { defender_state.modify_health(*health) },
            };
            AffectResult::Success
        },
    };
    (EffectResult { target: *effect.target, affect: result, }, hash_state)
}

fn run_effects(
    ref attacker_state: CombatantState,
    ref defender_state: CombatantState,
    mut effects: Span<Effect>,
    mut hash_state: HashState,
) -> Array<EffectResult> {
    let mut results: Array<EffectResult> = ArrayTrait::new();
    loop {
        match effects.pop_front() {
            Option::Some(effect) => {
                let (result, _hash_state) = run_effect(
                    ref attacker_state, ref defender_state, effect, hash_state,
                );
                hash_state = _hash_state;
                results.append(result);
            },
            Option::None => { break; },
        }
    };
    results
}

#[generate_trait]
impl CombatWorldImp of CombatWorldTraits {}

