pub mod calculations;
pub mod combat;
pub mod combatant;
pub mod result;
pub mod round_effect;
pub use combat::{Combat, CombatProgress, CombatTrait, Player, RoundResult};
pub use combatant::{CombatantState, CombatantStateTrait};
pub use result::{AttackResult, RoundEffectResult};
