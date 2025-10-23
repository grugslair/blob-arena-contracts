use ba_loadout::attributes::{ResistanceMods, Resistances, Vulnerabilities, VulnerabilityMods};
use sai_core_utils::BoolIntoBinary;
use crate::Player;


/// Represents the possible outcomes of an action action in the game
///
/// # Variants
/// * `NotAvailable` - The action is not available (e.g., on cooldown, invalid selection)
/// * `Stunned` - The actor was stunned and couldn't execute the action
/// * `Success` - The action succeeded, contains array of effect results from the action
/// * `Fail` - The action failed, contains array of effect results from the action
/// results
#[derive(Drop, Serde, Introspect, Default)]
pub enum ActionResult {
    #[default]
    NotAvailable,
    Stunned,
    Action: (u16, Array<EffectResult>),
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


/// Represents the possible outcomes or effects of an action in the game
///
/// # Variants
/// ## Basic Results
/// * `None` - No effect was applied
/// * `Applied` - A generic effect was successfully applied such as a DoT effect
/// * `Damage` - Damage was dealt, contains damage calculation details
///
/// ## Permanent Attribute Changes

/// * `Strength` - Strength was permanently modified
/// * `Vitality` - Vitality was permanently modified, includes health changes
/// * `Dexterity` - Dexterity was permanently modified
/// * `Luck` - Luck was permanently modified
/// * `Abilities` - All the abilities were modified
///
/// ## Resistance/Vulnerability Changes
/// * `StunResistance` - Stun resistance was permanently modified
/// * `BludgeonResistance` - Bludgeon resistance was permanently modified
/// * `MagicResistance` - Magic resistance was permanently modified
/// * `PierceResistance` - Pierce resistance was permanently modified
/// * `BludgeonVulnerability` - Bludgeon vulnerability was permanently modified
/// * `MagicVulnerability` - Magic vulnerability was permanently modified
/// * `PierceVulnerability` - Pierce vulnerability was permanently modified
/// * `Resistances` - Multiple resistances were modified
/// * `Vulnerabilities` - Multiple vulnerabilities were modified
///
/// ## Temporary Modifiers
/// * `StrengthTemp` - Temporary strength modifier applied
/// * `VitalityTemp` - Temporary vitality modifier applied, includes health changes
/// * `DexterityTemp` - Temporary dexterity modifier applied
/// * `LuckTemp` - Temporary luck modifier applied
/// * `StunResistanceTemp` - Temporary stun resistance modifier applied
/// * `BludgeonResistanceTemp` - Temporary bludgeon resistance modifier applied
/// * `MagicResistanceTemp` - Temporary magic resistance modifier applied
/// * `PierceResistanceTemp` - Temporary pierce resistance modifier applied
/// * `BludgeonVulnerabilityTemp` - Temporary bludgeon vulnerability modifier applied
/// * `MagicVulnerabilityTemp` - Temporary magic vulnerability modifier applied
/// * `PierceVulnerabilityTemp` - Temporary pierce vulnerability modifier applied
/// * `AbilitiesTemp` - Multiple temporary ability modifiers applied
/// * `ResistancesTemp` - Multiple temporary resistance modifiers applied
/// * `VulnerabilitiesTemp` - Multiple temporary vulnerability modifiers applied
///
/// ## Special Effects
/// * `Stun` - Stun chance effect was applied
/// * `Block` - Block effect applied with specified strength
///
/// ## Health Manipulation
/// * `Health` - Health was permanently modified
/// * `SetHealth` - Health was set to a specific value
/// * `FloorHealth` - Health was set to minimum of current or specified value
/// * `CeilHealth` - Health was set to maximum of current or specified value
/// * `HealthPercentMax` - Health was modified by percentage of max health
/// * `SetHealthPercentMax` - Health was set to percentage of max health
/// * `FloorHealthPercentMax` - Health floored to percentage of max health
/// * `CeilHealthPercentMax` - Health capped to percentage of max health
#[derive(Drop, Serde, PartialEq, Introspect)]
pub enum AffectResult {
    None,
    Applied,
    Stun: u8,
    Block: u8,
    Health: u8,
    Strength: u8,
    Vitality: VitalityResult,
    Dexterity: u8,
    Luck: u8,
    StunResistance: u8,
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
    StunResistanceTemp: i8,
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
    SetHealth: u8,
    FloorHealth: u8,
    CeilHealth: u8,
    HealthPercentMax: u8,
    SetHealthPercentMax: u8,
    FloorHealthPercentMax: u8,
    CeilHealthPercentMax: u8,
}

/// Represents the result of a damage calculation
///
/// # Fields
/// * `hp` - The amount of damage dealt
/// * `critical` - Whether the damage was a critical hit
#[derive(Drop, Serde, PartialEq, Introspect)]
pub struct DamageResult {
    pub hp: u8,
    pub critical: bool,
}

/// Represents the result of applying a vitality effect
///
/// # Fields
/// * `vitality` - The new vitality value after effect application
/// * `health` - The health change resulting from the vitality modification
#[derive(Drop, Serde, Copy, PartialEq, Introspect, Default)]
pub struct VitalityResult {
    pub vitality: u8,
    pub health: u8,
}

/// Represents the result of applying a temporary vitality modifier
///
/// # Fields
/// * `vitality` - The temporary vitality modifier applied (can be negative)
/// * `health` - The health change resulting from the temporary vitality modification
#[derive(Drop, Serde, Copy, PartialEq, Introspect, Default)]
pub struct VitalityTempResult {
    pub vitality: i8,
    pub health: u8,
}

/// Represents the result of applying permanent ability score changes
///
/// # Fields
/// * `strength` - The new strength value after effect application
/// * `vitality` - The new vitality value after effect application
/// * `dexterity` - The new dexterity value after effect application
/// * `luck` - The new luck value after effect application
/// * `health` - The health change resulting from ability modifications
#[derive(Drop, Serde, Copy, PartialEq, Introspect, Default)]
pub struct AbilitiesResult {
    pub strength: u8,
    pub vitality: u8,
    pub dexterity: u8,
    pub luck: u8,
    pub health: u8,
}

/// Represents the result of applying temporary ability score modifiers
///
/// # Fields
/// * `strength` - The temporary strength modifier applied (can be negative)
/// * `vitality` - The temporary vitality modifier applied (can be negative)
/// * `dexterity` - The temporary dexterity modifier applied (can be negative)
/// * `luck` - The temporary luck modifier applied (can be negative)
/// * `health` - The health change resulting from temporary ability modifications
#[derive(Drop, Serde, Copy, PartialEq, Introspect, Default)]
pub struct AbilitiesTempResult {
    pub strength: i8,
    pub vitality: i8,
    pub dexterity: i8,
    pub luck: i8,
    pub health: u8,
}

/// Represents the result of a round effect application
///
/// # Fields
/// * `source` - The player who initiated the effect
/// * `target` - The player who received the effect
/// * `affect` - The result of applying the effect
#[derive(Drop, Serde, PartialEq, Introspect)]
pub struct RoundEffectResult {
    pub source: Player,
    pub target: Player,
    pub affect: AffectResult,
}

