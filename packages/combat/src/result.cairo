use ba_loadout::attack::Target;
use ba_loadout::attributes::{AbilityMods, ResistanceMods, VulnerabilityMods};
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
#[derive(Drop, Serde, PartialEq, Introspect)]
pub enum AffectResult {
    None,
    Strength: i8,
    Vitality: i8,
    Dexterity: i8,
    Luck: i8,
    BludgeonResistance: i8,
    MagicResistance: i8,
    PierceResistance: i8,
    BludgeonVulnerability: i16,
    MagicVulnerability: i16,
    PierceVulnerability: i16,
    Abilities: AbilityMods,
    Resistances: ResistanceMods,
    Vulnerabilities: VulnerabilityMods,
    StrengthTemp: i8,
    VitalityTemp: i8,
    DexterityTemp: i8,
    LuckTemp: i8,
    BludgeonResistanceTemp: i8,
    MagicResistanceTemp: i8,
    PierceResistanceTemp: i8,
    BludgeonVulnerabilityTemp: i16,
    MagicVulnerabilityTemp: i16,
    PierceVulnerabilityTemp: i16,
    AbilitiesTemp: AbilityMods,
    ResistancesTemp: ResistanceMods,
    VulnerabilitiesTemp: VulnerabilityMods,
    Damage: DamageResult,
    Stun: u8,
    Block: u8,
    Health: i8,
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

