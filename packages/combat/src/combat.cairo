use ba_loadout::attack::{AbilityAffect, Affect, Effect, Target};
use ba_utils::UpdateHashToU128;
use core::poseidon::HashState;
use crate::calculations::{damage_calculation, did_critical};
use crate::result::{AffectResult, DamageResult, EffectResult};
use crate::{CombatantState, CombatantStateTrait};

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


fn run_effects(
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
