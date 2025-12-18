pub mod action {
    pub mod action;
    mod contract;
    pub mod effect;
    pub mod interface;
    pub use action::{Action, ActionWithName, ActionWithNameTrait, IdTagAction, get_action_id};
    pub use effect::{
        Abilities, Affect, Damage, DamageType, Effect, HealthMod, HealthModType, Modifiers,
        Recipient,
    };
    pub use interface::{
        IAction, IActionAdmin, IActionAdminDispatcher, IActionAdminDispatcherTrait,
        IActionDispatcher, IActionDispatcherTrait, maybe_create_actions,
    };
}
pub mod attributes;
pub mod loadout_amma;
pub use attributes::{Attributes, AttributesTrait, PartialAttributes};

pub mod interface;
pub mod loadout_classic;
pub use interface::get_loadout;

#[cfg(test)]
mod test {
    mod ability;
}
