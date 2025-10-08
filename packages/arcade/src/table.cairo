use ba_combat::combat::PlayerOrNone;
use ba_combat::{AttackResult, Combat, CombatantState, RoundEffectResult, RoundResult};
use ba_loadout::attributes::Attributes;
use starknet::ContractAddress;
use crate::attempt::ArcadeProgress;


/// Represents a player's arcade game attempt with all associated configuration and state
///
/// # Fields
/// * `player` - The wallet address of the player making the attempt
/// * `collection_address` - The NFT collection contract address
/// * `token_id` - The specific NFT token ID being used
/// * `expiry` - Timestamp when this attempt expires
/// * `attributes` - The combatant's calculated attributes for this attempt
/// * `attacks` - Available attacks for this attempt (as a span for efficiency)
/// * `health_regen` - Health regeneration amount between stages
/// * `respawns` - Number of respawns/lives remaining
/// * `stage` - Current stage number in the arcade progression
/// * `phase` - Current phase of the arcade attempt (Active, Won, Lost, etc.)
#[derive(Drop, Serde, Introspect)]
pub struct ArcadeAttemptTable {
    pub player: ContractAddress,
    pub collection_address: ContractAddress,
    pub token_id: u256,
    pub expiry: u64,
    pub attributes: Attributes,
    pub attacks: Span<felt252>,
    pub health_regen: u8,
    pub respawns: u32,
    pub stage: u32,
    pub phase: ArcadeProgress,
}

/// Represents the initial configuration and state of a combat encounter within an arcade stage
///
/// Stores the starting conditions for a combat, including player health and opponent attributes.
/// This is used to track combat parameters and provide context for combat results.
///
/// # Fields
/// * `attempt` - Unique identifier of the arcade attempt this combat belongs to
/// * `combat` - Combat number within the current stage (0-based)
/// * `stage` - Stage number where this combat occurs
/// * `starting_player_health` - Player's health at the beginning of this combat
/// * `starting_opponent_attributes` - Complete attribute set of the opponent for this combat
#[derive(Drop, Serde, Introspect)]
pub struct CombatTable {
    pub attempt: felt252,
    pub combat: u32,
    pub stage: u32,
    pub starting_player_health: u8,
    pub starting_opponent_attributes: Attributes,
}

/// Represents the complete result of a single combat round in an arcade attempt
///
/// Contains all information about what happened during a specific round, including
/// combatant states, attacks used, and the effects that occurred.
///
/// # Fields
/// * `attempt` - Unique identifier of the arcade attempt this round belongs to
/// * `combat` - Combat number within the current stage
/// * `round` - Round number within the current combat
/// * `player_state` - Player's combatant state after this round
/// * `opponent_state` - Opponent's combatant state after this round
/// * `player_attack` - Attack ID used by the player this round
/// * `opponent_attack` - Attack ID used by the opponent this round
/// * `first` - Who acted first this round (Player1, Player2, or None)
/// * `round_effect_results` - Results of any ongoing effects that triggered
/// * `attack_results` - Results of the attacks that were executed
/// * `progress` - Updated progress state after this round
#[derive(Drop, Serde, Introspect)]
pub struct ArcadeRoundTable {
    pub attempt: felt252,
    pub combat: u32,
    pub round: u32,
    pub player_state: CombatantState,
    pub opponent_state: CombatantState,
    pub player_attack: felt252,
    pub opponent_attack: felt252,
    pub first: PlayerOrNone,
    pub round_effect_results: Array<RoundEffectResult>,
    pub attack_results: Array<AttackResult>,
    pub progress: ArcadeProgress,
}

/// Tracks the last time a specific attack was used in an arcade attempt
///
/// Used for cooldown management and attack usage restrictions.
///
/// # Fields
/// * `attempt` - Unique identifier of the arcade attempt
/// * `combat` - Combat number when the attack was last used
/// * `attack` - The attack ID that was used
/// * `round` - Round number when the attack was last used
#[derive(Drop, Serde, Introspect)]
pub struct AttackLastUsed {
    pub attempt: felt252,
    pub combat: u32,
    pub attack: felt252,
    pub round: u32,
}


/// Trait for converting different combat result types into arcade round results
///
/// Provides a common interface for transforming combat data structures into
/// the standardized ArcadeRoundResult format used for storage and querying.
pub trait AttemptRoundTrait<T> {
    /// Converts the implementing type into an ArcadeRoundResult
    ///
    /// # Arguments
    /// * `self` - The combat result to convert
    /// * `attempt` - The arcade attempt identifier
    /// * `combat` - The combat number within the attempt
    ///
    /// # Returns
    /// An ArcadeRoundResult containing all the round information
    fn to_arcade_round(self: T, attempt: felt252, combat: u32) -> ArcadeRoundTable;
}


impl CombatToAttemptRoundImpl of AttemptRoundTrait<Combat> {
    fn to_arcade_round(self: Combat, attempt: felt252, combat: u32) -> ArcadeRoundTable {
        ArcadeRoundTable {
            attempt: attempt,
            combat: combat,
            round: self.round,
            player_state: self.state_1,
            opponent_state: self.state_2,
            player_attack: self.attack_1,
            opponent_attack: self.attack_2,
            first: self.first.into(),
            round_effect_results: self.round_effect_results,
            attack_results: self.attack_results,
            progress: self.progress.into(),
        }
    }
}

impl RoundResultToAttemptRoundImpl of AttemptRoundTrait<RoundResult> {
    fn to_arcade_round(self: RoundResult, attempt: felt252, combat: u32) -> ArcadeRoundTable {
        let [player_state, opponent_state] = self.states;
        let [player_attack, opponent_attack] = self.attacks;
        ArcadeRoundTable {
            attempt: attempt,
            combat: combat,
            round: self.round,
            player_state,
            opponent_state,
            player_attack,
            opponent_attack,
            first: self.first.into(),
            round_effect_results: self.round_effect_results,
            attack_results: self.attack_results,
            progress: self.progress.into(),
        }
    }
}


#[starknet::contract]
pub mod arcade_round_result_model {
    use super::ArcadeRoundTable;
    #[storage]
    struct Storage {}
    #[abi(embed_v0)]
    impl ArcadeRoundResultModelImpl =
        beacon_entity::interface::ISaiModelImpl<ContractState, ArcadeRoundTable>;
}

#[cfg(test)]
mod tests {
    use beacon_entity::get_schema_size;
    use super::{ArcadeAttemptTable, ArcadeRoundTable};


    #[test]
    fn table_size_test() {
        println!("ArcadeRound size: {}", get_schema_size::<ArcadeRoundTable>());
        println!("ArcadeAttempt size: {}", get_schema_size::<ArcadeAttemptTable>());
    }
}
