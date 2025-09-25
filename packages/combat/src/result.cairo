use ba_loadout::attack::Target;
use sai_core_utils::BoolIntoBinary;
use crate::Player;


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
    Success: Array<EffectResult>,
    Fail: Array<EffectResult>,
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
/// * `Applied` - The effect was successfully applied
/// * `Damage` - A complex damage result containing damage type and amount
#[derive(Drop, Serde, PartialEq, Default, Introspect)]
pub enum AffectResult {
    #[default]
    None,
    Applied,
    Damage: DamageResult,
}

/// Represents the result of a damage calculation
/// * `hp` - The amount of damage dealt
/// * `critical` - Whether the damage was a critical hit
#[derive(Drop, Serde, PartialEq, Introspect)]
pub struct DamageResult {
    pub hp: u8,
    pub critical: bool,
}

pub struct RoundEffectResult {
    pub attacker: Player,
    pub defender: Player,
    pub affect: AffectResult,
}

