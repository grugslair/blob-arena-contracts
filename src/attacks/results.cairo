use super::{Target, Stat};
use crate::core::BoolIntoOneZero;
use crate::stats::{IStats, IStatsTrait};

/// Represents the outcome of a round in combat
///
/// # Fields
/// * `combat_id` - Unique identifier for the combat instance
/// * `round` - The round number within the combat
/// * `attacks` - Collection of individual attack results that occurred during this round
///
/// This event is emitted at the end of each combat round to record all attack outcomes.
#[dojo::event]
#[derive(Drop, Serde, starknet::Event)]
struct RoundResult {
    #[key]
    combat_id: felt252,
    #[key]
    round: u32,
    attacks: Span<AttackResult>,
}

/// Represents the outcome of an attack action in the blob arena game
/// # Fields
/// * `combatant_id` - The unique identifier of the attacking entity
/// * `attack` - The id of the attack used
/// * `target` - The id of the target being attacked
/// * `result` - The outcome of the attack, represented as an AttackOutcomes enum
#[derive(Drop, Serde, Introspect)]
struct AttackResult {
    combatant_id: felt252,
    attack: felt252,
    target: felt252,
    result: AttackOutcomes,
}

/// Represents the possible outcomes of an attack action in the game
/// # Variants
/// * `Failed` - The attack attempt failed completely (attack not available or cooled down)
/// * `Stunned` - The attacker was stunned and couldn't complete the attack
/// * `Miss` - The attack missed, contains array of effect results
/// * `Hit` - The attack successfully hit, contains array of effect results
#[derive(Drop, Serde, Introspect)]
enum AttackOutcomes {
    Failed,
    Stunned,
    Miss: Array<EffectResult>,
    Hit: Array<EffectResult>,
}

/// Represents the result of an effect application in the battle system
///
/// # Fields
/// * `target` - The target enum that was affected by the effect
/// * `affect` - The result of applying the effect to the target
#[derive(Drop, Serde, PartialEq, Introspect)]
struct EffectResult {
    target: Target,
    affect: AffectResult,
}


/// Represents the possible outcomes or effects of an action in the game.
/// # Variants
/// * `Health` - A change in health points (positive for healing, negative for damage)
/// * `Damage` - A complex damage result containing damage type and amount
/// * `Stats` - Multiple stat modifications represented by IStats interface
/// * `Stat` - A single stat modification
/// * `Stun` - Overall stun chance
#[derive(Drop, Serde, PartialEq, Introspect)]
enum AffectResult {
    Health: i32,
    Damage: DamageResult,
    Stats: IStats,
    Stat: Stat,
    Stun: u8,
}

/// Represents the result of a damage calculation
/// * `damage` - The amount of damage dealt
/// * `critical` - Whether the damage was a critical hit
#[derive(Drop, Serde, PartialEq, Introspect)]
struct DamageResult {
    damage: u8,
    critical: bool,
}

#[derive(Drop, Default)]
struct AttackEffect {
    criticals: u32,
    damage: u32,
    stats: IStats,
    stun: u8,
    health: i32,
}

#[generate_trait]
impl AttackOutcomesImpl of AttackOutcomesTrait {
    fn effects(self: @AttackOutcomes) -> (AttackEffect, AttackEffect) {
        let mut player: AttackEffect = Default::default();
        let mut opponent: AttackEffect = Default::default();
        match self {
            AttackOutcomes::Hit(effects) |
            AttackOutcomes::Miss(effects) => {
                for effect in effects.span() {
                    match effect.affect {
                        AffectResult::Damage(affect) => {
                            match effect.target {
                                Target::Player => {
                                    player.damage += (*affect.damage).into();
                                    player.criticals += (*affect.critical).into();
                                },
                                Target::Opponent => {
                                    opponent.damage += (*affect.damage).into();
                                    opponent.criticals += (*affect.critical).into();
                                },
                            }
                        },
                        AffectResult::Stats(affect) => {
                            match effect.target {
                                Target::Player => { player.stats += *affect; },
                                Target::Opponent => { opponent.stats += *affect; },
                            }
                        },
                        AffectResult::Stat(affect) => {
                            match effect.target {
                                Target::Player => {
                                    player.stats.add_stat(*affect.stat, *affect.amount);
                                },
                                Target::Opponent => {
                                    opponent.stats.add_stat(*affect.stat, *affect.amount);
                                },
                            }
                        },
                        AffectResult::Stun(affect) => {
                            match effect.target {
                                Target::Player => { player.stun += *affect; },
                                Target::Opponent => { opponent.stun += *affect; },
                            }
                        },
                        AffectResult::Health(affect) => {
                            match effect.target {
                                Target::Player => { player.health += *affect; },
                                Target::Opponent => { opponent.health += *affect; },
                            }
                        },
                    }
                }
            },
            _ => {},
        };
        (player, opponent)
    }
}

#[generate_trait]
impl AttackResultImpl of AttackResultTrait {
    fn effects(self: @AttackResult) -> (AttackEffect, AttackEffect) {
        self.result.effects()
    }
}
