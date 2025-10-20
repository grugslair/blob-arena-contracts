use ba_loadout::attack::IAttackDispatcher;
use ba_utils::{ExternalCalls, Randomness};
use starknet::ClassHash;
use crate::combat::AttackCheck;
use crate::{CombatantState, RoundResult};

#[starknet::contract]
mod combat {
    use ba_loadout::attack::IAttackDispatcher;
    use ba_utils::Randomness;
    use crate::combat::AttackCheck;
    use crate::{CombatTrait, CombatantState, RoundResult};

    #[storage]
    struct Storage {}

    /// Executes a single combat round between two combatants
    ///
    /// Processes one round of combat by applying attacks from both combatants,
    /// resolving damage, effects, and state changes. Uses provided randomness
    /// for combat calculations and returns updated randomness state.
    ///
    /// # Arguments
    /// * `id` - Unique identifier for this combat session
    /// * `round` - Current round number in the combat sequence
    /// * `state_1` - Current state of the first combatant (health, effects, etc.)
    /// * `state_2` - Current state of the second combatant (health, effects, etc.)
    /// * `attack_1` - Attack identifier chosen by the first combatant
    /// * `attack_2` - Attack identifier chosen by the second combatant
    /// * `attack_check_1` - Pre-validated attack data for the first combatant
    /// * `attack_check_2` - Pre-validated attack data for the second combatant
    /// * `attack_dispatcher` - Interface for resolving attack effects and damage
    /// * `randomness` - Current randomness state for combat calculations
    ///
    /// # Returns
    /// * `RoundResult` - Complete results of the combat round including damage, effects, and final
    /// states
    /// * `Randomness` - Updated randomness state after combat calculations
    #[external(v0)]
    fn run_round(
        ref self: ContractState,
        id: felt252,
        round: u32,
        state_1: CombatantState,
        state_2: CombatantState,
        attack_1: felt252,
        attack_2: felt252,
        attack_check_1: AttackCheck,
        attack_check_2: AttackCheck,
        attack_dispatcher: IAttackDispatcher,
        randomness: Randomness,
    ) -> (RoundResult, Randomness) {
        let mut combat = CombatTrait::new(
            id,
            round,
            state_1,
            state_2,
            attack_1,
            attack_2,
            attack_check_1,
            attack_check_2,
            randomness,
            attack_dispatcher,
        );
        combat.run_round();
        combat.to_round_and_randomness()
    }
}

/// Library call wrapper for executing combat rounds via class hash
///
/// Provides a way to execute combat rounds through library calls using a specific
/// class hash. This allows for upgradeable combat logic while maintaining the same
/// interface. Delegates to the combat contract's run_round function.
///
/// # Arguments
/// * `class_hash` - The class hash of the combat contract to call
/// * `id` - Unique identifier for this combat session
/// * `round` - Current round number in the combat sequence
/// * `state_1` - Current state of the first combatant
/// * `state_2` - Current state of the second combatant
/// * `attack_1` - Attack identifier chosen by the first combatant
/// * `attack_2` - Attack identifier chosen by the second combatant
/// * `attack_check_1` - Pre-validated attack data for the first combatant
/// * `attack_check_2` - Pre-validated attack data for the second combatant
/// * `attack_dispatcher` - Interface for resolving attack effects and damage
/// * `randomness` - Current randomness state for combat calculations
///
/// # Returns
/// * `RoundResult` - Complete results of the combat round
/// * `Randomness` - Updated randomness state after combat calculations
pub fn library_run_round(
    class_hash: ClassHash,
    id: felt252,
    round: u32,
    state_1: CombatantState,
    state_2: CombatantState,
    attack_1: felt252,
    attack_2: felt252,
    attack_check_1: AttackCheck,
    attack_check_2: AttackCheck,
    attack_dispatcher: IAttackDispatcher,
    randomness: Randomness,
) -> (RoundResult, Randomness) {
    class_hash
        .call_library(
            selector!("run_round"),
            (
                id,
                round,
                state_1,
                state_2,
                attack_1,
                attack_2,
                attack_check_1,
                attack_check_2,
                attack_dispatcher,
                randomness,
            ),
        )
}
