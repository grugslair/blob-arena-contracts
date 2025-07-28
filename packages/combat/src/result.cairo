use ba_loadout::ability::{DAbilities, DAbilitiesTrait};
use ba_loadout::attack::{AbilityAffect, Target};
use sai_core_utils::BoolIntoBinary;

/// Represents the outcome of a round in combat
///
/// # Fields
/// * `combat_id` - Unique identifier for the combat instance
/// * `round` - The round number within the combat
/// * `attacks` - Collection of individual attack results that occurred during this round
///
/// This event is emitted at the end of each combat round to record all attack outcomes.

#[derive(Drop, Serde, Introspect)]
pub struct RoundResult {
    pub combat_id: felt252,
    pub round: u32,
    pub attacks: Span<AttackResult>,
}

/// Represents the outcome of an attack action in the blob arena game
/// # Fields
/// * `combatant_id` - The unique identifier of the attacking entity
/// * `attack` - The id of the attack used
/// * `target` - The id of the target being attacked
/// * `result` - The outcome of the attack, represented as an AttackOutcomes pub enum
#[derive(Drop, Serde, Introspect)]
pub struct AttackResult {
    pub combatant_id: felt252,
    pub attack: felt252,
    pub target: felt252,
    pub result: AttackOutcomes,
}

/// Represents the possible outcomes of an attack action in the game
/// # Variants
/// * `Failed` - The attack attempt failed completely (attack not available or cooled down)
/// * `Stunned` - The attacker was stunned and couldn't complete the attack
/// * `Miss` - The attack missed, contains array of effect results
/// * `Hit` - The attack successfully hit, contains array of effect results
#[derive(Drop, Serde, Introspect, Default)]
pub enum AttackOutcomes {
    #[default]
    Failed,
    Stunned,
    Miss: Array<EffectResult>,
    Hit: Array<EffectResult>,
}

/// Represents the result of an effect application in the battle system
///
/// # Fields
/// * `target` - The target pub enum that was affected by the effect
/// * `affect` - The result of applying the effect to the target
#[derive(Drop, Serde, PartialEq, Introspect)]
pub struct EffectResult {
    pub target: Target,
    pub affect: AffectResult,
}


/// Represents the possible outcomes or effects of an action in the game.
/// # Variants
/// * `Health` - A change in health points (positive for healing, negative for damage)
/// * `Damage` - A complex damage result containing damage type and amount
/// * `Abilities` - Multiple ability modifications represented by DAbilities interface
/// * `Ability` - A single ability modification
/// * `Stun` - Overall stun chance
#[derive(Drop, Serde, PartialEq, Default, Introspect)]
pub enum AffectResult {
    #[default]
    Health: i32,
    Damage: DamageResult,
    Abilities: DAbilities,
    Ability: AbilityAffect,
    Stun: u8,
}

/// Represents the result of a damage calculation
/// * `damage` - The amount of damage dealt
/// * `critical` - Whether the damage was a critical hit
#[derive(Drop, Serde, PartialEq, Introspect)]
pub struct DamageResult {
    pub damage: u32,
    pub critical: bool,
}

#[derive(Drop, Introspect, Default)]
pub struct AttackEffect {
    pub criticals: u32,
    pub damage: u32,
    pub abilities: DAbilities,
    pub stun: u8,
    pub health: i32,
}

#[generate_trait]
impl AttackOutcomesImpl of AttackOutcomesTrait {
    fn effects(self: @AttackOutcomes) -> (AttackEffect, AttackEffect) {
        let mut player: AttackEffect = Default::default();
        let mut opponent: AttackEffect = Default::default();
        if let AttackOutcomes::Hit(effects) | AttackOutcomes::Miss(effects) = self {
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
                    AffectResult::Abilities(affect) => {
                        match effect.target {
                            Target::Player => { player.abilities += *affect; },
                            Target::Opponent => { opponent.abilities += *affect; },
                        }
                    },
                    AffectResult::Ability(affect) => {
                        match effect.target {
                            Target::Player => {
                                player.abilities.add_ability(*affect.ability, *affect.amount);
                            },
                            Target::Opponent => {
                                opponent.abilities.add_ability(*affect.ability, *affect.amount);
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
        }
        (player, opponent)
    }
}

#[generate_trait]
impl AttackResultImpl of AttackResultTrait {
    fn effects(self: @AttackResult) -> (AttackEffect, AttackEffect) {
        self.result.effects()
    }
}
