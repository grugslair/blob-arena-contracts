pub mod attack {
    pub mod types;
    pub use types::{
        AbilityAffect, Affect, Attack, AttackWithName, AttackWithNameTrait, Effect, IdTagAttack,
        Target, get_attack_id,
    };
    mod contract;
    pub mod interface;
    pub use interface::{
        IAttack, IAttackAdmin, IAttackAdminDispatcher, IAttackAdminDispatcherTrait,
        IAttackDispatcher, IAttackDispatcherTrait,
    };
}
pub mod ability;
pub mod amma_contract;
pub mod arena_contract;
pub mod interface;
pub use interface::get_loadout;

#[cfg(test)]
mod test {
    mod ability;
}
