use core::poseidon::HashState;
use blob_arena::{
    attacks::{
        Effect, Affect, Target, Damage, Stat, results::{EffectResult, AffectResult, DamageResult}
    },
    combatants::{CombatantState, CombatantTrait, CombatantStateTrait},
    combat::calculations::{damage_calculation, did_critical}, hash::{HashUpdate, UpdateHashToU128}
};


#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
enum Phase {
    Setup,
    Commit,
    Reveal,
    Ended: felt252,
}

#[dojo::model]
#[derive(Drop, Serde, Copy, Introspect)]
struct CombatState {
    #[key]
    id: felt252,
    round: u32,
    phase: Phase,
    block_number: u64,
}

#[generate_trait]
impl PhaseImpl of PhaseTrait {
    fn assert_running(self: @Phase) {
        assert(self.is_running(), 'Combat not running')
    }
    fn is_running(self: @Phase) -> bool {
        match *self {
            Phase::Commit | Phase::Reveal => true,
            _ => false
        }
    }
}

fn run_effect(
    ref attacker_state: CombatantState,
    ref defender_state: CombatantState,
    effect: @Effect,
    move_n: u32,
    hash_state: HashState,
) -> EffectResult {
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
            let mut seed = hash_state.update_to_u128(move_n);

            let critical = did_critical(*damage.critical, attacker_state.stats.luck, ref seed);

            let damage = damage_calculation(*damage.power, attacker_state.stats.strength, critical);
            match effect.target {
                Target::Player => { attacker_state.modify_health::<i16>(-(damage.into())) },
                Target::Opponent => { defender_state.modify_health::<i16>(-(damage.into())) },
            };
            AffectResult::Damage(DamageResult { critical, damage })
        },
        Affect::Stun(stun) => {
            match effect.target {
                Target::Player => { attacker_state.apply_stun(*stun) },
                Target::Opponent => { defender_state.apply_stun(*stun) },
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
    EffectResult { target: *effect.target, affect: result, }
}

fn run_effects(
    ref attacker_state: CombatantState,
    ref defender_state: CombatantState,
    mut effects: Span<Effect>,
    mut hash_state: HashState,
) -> Span<EffectResult> {
    let mut results: Array<EffectResult> = ArrayTrait::new();
    for n in 0
        ..effects
            .len() {
                results
                    .append(
                        run_effect(
                            ref attacker_state, ref defender_state, effects.at(n), n, hash_state,
                        )
                    );
            };
    results.span()
}
