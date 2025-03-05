use super::Target;


/// Represents the outcome of a round in combat
///
/// # Fields
/// * `combat_id` - Unique identifier for the combat instance
/// * `round` - The round number within the combat
/// * `attacks` - Collection of individual attack results that occurred during this round
///
/// This event is emitted at the end of each combat round to record all attack outcomes.
#[dojo::event]
#[derive(Drop, Serde)]
struct RoundResult {
    #[key]
    combat_id: felt252,
    #[key]
    round: u32,
    attacks: Array<AttackResult>,
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

/// Represents the possible outcomes of an affect action
/// # Variants
/// * `Success` - The affect action was successful without causing damage
/// * `Damage(DamageResult)` - The affect action resulted in damage, containing damage details
#[derive(Drop, Serde, PartialEq, Introspect)]
enum AffectResult {
    Success,
    Damage: DamageResult,
}

/// Represents the result of a damage calculation
/// * `damage` - The amount of damage dealt
/// * `critical` - Whether the damage was a critical hit
#[derive(Drop, Serde, PartialEq, Introspect)]
struct DamageResult {
    damage: u8,
    critical: bool,
}
