use ba_loadout::attributes::{ResistanceMods, Resistances, Vulnerabilities, VulnerabilityMods};
use sai_core_utils::BoolIntoBinary;
use crate::Player;


/// Represents the possible outcomes of an attack action in the game
/// # Variants
/// * `Failed` - The attack attempt failed completely (attack not available or cooled down)
/// * `Stunned` - The attacker was stunned and couldn't complete the attack
/// * `Miss` - The attack missed, contains array of effect results
/// * `Hit` - The attack successfully hit, contains array of effect results
#[derive(Drop, Serde, Introspect, Default)]
pub enum AttackResult {
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
    pub target: Player,
    pub affect: AffectResult,
}


/// Represents the possible outcomes or effects of an action in the game.
/// # Variants
/// * `Applied` - The effect was successfully applied
/// * `Damage` - A complex damage result containing damage type and amount
#[derive(Drop, Serde, PartialEq, Introspect)]
pub enum AffectResult {
    None,
    Applied,
    Strength: u8,
    Vitality: VitalityResult,
    Dexterity: u8,
    Luck: u8,
    BludgeonResistance: u8,
    MagicResistance: u8,
    PierceResistance: u8,
    BludgeonVulnerability: u16,
    MagicVulnerability: u16,
    PierceVulnerability: u16,
    Abilities: AbilitiesResult,
    Resistances: Resistances,
    Vulnerabilities: Vulnerabilities,
    StrengthTemp: i8,
    VitalityTemp: VitalityTempResult,
    DexterityTemp: i8,
    LuckTemp: i8,
    BludgeonResistanceTemp: i8,
    MagicResistanceTemp: i8,
    PierceResistanceTemp: i8,
    BludgeonVulnerabilityTemp: i16,
    MagicVulnerabilityTemp: i16,
    PierceVulnerabilityTemp: i16,
    AbilitiesTemp: AbilitiesTempResult,
    ResistancesTemp: ResistanceMods,
    VulnerabilitiesTemp: VulnerabilityMods,
    Damage: DamageResult,
    Stun: u8,
    Block: u8,
    Health: u8,
}

/// Represents the result of a damage calculation
/// * `hp` - The amount of damage dealt
/// * `critical` - Whether the damage was a critical hit
#[derive(Drop, Serde, PartialEq, Introspect)]
pub struct DamageResult {
    pub hp: u8,
    pub critical: bool,
}

#[derive(Drop, Serde, Copy, PartialEq, Introspect, Default)]
pub struct VitalityResult {
    pub vitality: u8,
    pub health: u8,
}

#[derive(Drop, Serde, Copy, PartialEq, Introspect, Default)]
pub struct VitalityTempResult {
    pub vitality: i8,
    pub health: u8,
}

#[derive(Drop, Serde, Copy, PartialEq, Introspect, Default)]
pub struct AbilitiesResult {
    pub strength: u8,
    pub vitality: u8,
    pub dexterity: u8,
    pub luck: u8,
    pub health: u8,
}

#[derive(Drop, Serde, Copy, PartialEq, Introspect, Default)]
pub struct AbilitiesTempResult {
    pub strength: i8,
    pub vitality: i8,
    pub dexterity: i8,
    pub luck: i8,
    pub health: u8,
}

#[derive(Drop, Serde, PartialEq, Introspect)]
pub struct RoundEffectResult {
    pub source: Player,
    pub target: Player,
    pub affect: AffectResult,
}

