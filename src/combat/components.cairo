use core::poseidon::HashState;
use starknet::ContractAddress;
use blob_arena::{
    attacks::{
        Effect, Affect, Target, Damage, Stat, results::{EffectResult, AffectResult, DamageResult},
    },
    combatants::{CombatantState, CombatantTrait, CombatantStateTrait},
    combat::calculations::{damage_calculation, did_critical}, hash::{HashUpdate, UpdateHashToU128},
    iter::Iteration,
};
use crate::erc721::ERC721Token;


/// Phase represents the different states of a combat encounter
///
/// # Variants
/// * `None` - Initial state before combat is created
/// * `Created` - Combat has been created but not yet started
/// * `Commit` - Players are submitting their move commitments
/// * `Reveal` - Players are revealing their committed moves
/// * `Ended(felt252)` - Combat has ended with a winner ID
#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
enum Phase {
    None,
    Created,
    Commit,
    Reveal,
    Ended: felt252,
}

/// Represents the state of a combat encounter in the game.
///
/// Game Model
///
/// # Fields
/// * `id` - A unique identifier for the combat state
/// * `phase` - The current phase of combat (e.g., attack, defense)
/// * `round` - The current round number in the combat sequence the first round is 1
///
/// The CombatState model is used to track and manage the progression of combat encounters,
/// storing essential information about the current state of battle.
///
#[dojo::model]
#[derive(Drop, Serde, Copy, Introspect)]
struct CombatState {
    #[key]
    id: felt252,
    phase: Phase,
    round: u32,
}

#[derive(Copy, Drop, Serde, PartialEq)]
enum AttackCooledDown {
    False,
    True: bool,
}

/// Tracks consecutive wins in combat for players
///
/// # Fields
/// * `player` - The contract address of the player
/// * `current` - The current number of consecutive wins
/// * `token_max` - The maximum number of consecutive wins of a single token
/// * `max` - The all-time maximum number of consecutive wins achieved
#[dojo::model]
#[derive(Drop, Serde)]
struct ConsecutiveWins {
    #[key]
    player: ContractAddress,
    current: u64,
    token_max: u64,
    max: u64,
}

/// Tracks the number of consecutive wins for a specific player's token
///
/// # Fields
///
/// * `player` - ContractAddress of the player who owns the token
/// * `token` - ERC721Token that is being tracked
/// * `current` - Current number of consecutive wins for this token
/// * `max` - Maximum number of consecutive wins achieved by this token
#[dojo::model]
#[derive(Drop, Serde)]
struct ConsecutiveTokenWins {
    #[key]
    player: ContractAddress,
    #[key]
    token: ERC721Token,
    current: u64,
    max: u64,
}

#[derive(Copy, Drop, Serde, PartialEq)]
enum CombatProgress {
    Active,
    Ended: [felt252; 2],
}


#[generate_trait]
impl PhaseImpl of PhaseTrait {
    fn assert_running(self: @Phase) {
        assert(self.is_running(), 'Combat not running')
    }
    fn assert_commit(self: @Phase) {
        assert(*self == Phase::Commit, 'Not in commit phase')
    }
    fn assert_reveal(self: @Phase) {
        assert(*self == Phase::Reveal, 'Not in reveal phase')
    }
    fn assert_created(self: @Phase) {
        assert(*self == Phase::Created, 'Not in creation phase')
    }
    fn assert_none(self: @Phase) {
        assert(*self == Phase::None, 'Combat already created')
    }
    fn is_running(self: @Phase) -> bool {
        match *self {
            Phase::Commit | Phase::Reveal => true,
            _ => false,
        }
    }
    fn assert_no_winner(self: @Phase) {
        match *self {
            Phase::Ended(_) => panic!("Combat already ended"),
            _ => {},
        }
    }
}

fn run_effect(
    ref attacker_state: CombatantState,
    ref defender_state: CombatantState,
    effect: Effect,
    move_n: u32,
    hash_state: HashState,
) -> EffectResult {
    let result = match effect.affect {
        Affect::Stats(stats_effect) => {
            AffectResult::Stats(
                match effect.target {
                    Target::Player => { attacker_state.apply_buffs(stats_effect) },
                    Target::Opponent => { defender_state.apply_buffs(stats_effect) },
                },
            )
        },
        Affect::Stat(Stat {
            stat, amount,
        }) => {
            let change = match effect.target {
                Target::Player => { attacker_state.apply_buff(stat, amount) },
                Target::Opponent => { defender_state.apply_buff(stat, amount) },
            };
            AffectResult::Stat(Stat { stat, amount: change })
        },
        Affect::Damage(damage) => {
            let mut seed = hash_state.update_to_u128(move_n);

            let critical = did_critical(damage.critical, attacker_state.stats.luck, ref seed);

            let damage = damage_calculation(damage.power, attacker_state.stats.strength, critical);
            match effect.target {
                Target::Player => { attacker_state.modify_health::<i16>(-(damage.into())) },
                Target::Opponent => { defender_state.modify_health::<i16>(-(damage.into())) },
            };
            AffectResult::Damage(DamageResult { critical, damage })
        },
        Affect::Stun(stun) => {
            match effect.target {
                Target::Player => { attacker_state.apply_stun(stun) },
                Target::Opponent => { defender_state.apply_stun(stun) },
            };
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
    for (n, effect) in effects.enumerate() {
        results.append(run_effect(ref attacker_state, ref defender_state, effect, n, hash_state));
    };
    results
}
