pub mod attack {
    pub mod attack;
    mod contract;
    pub mod effect;
    pub mod interface;
    pub use attack::{Attack, AttackWithName, AttackWithNameTrait, IdTagAttack, get_attack_id};
    pub use effect::{Affect, Damage, DamageType, Effect, Target};
    pub use interface::{
        IAttack, IAttackAdmin, IAttackAdminDispatcher, IAttackAdminDispatcherTrait,
        IAttackDispatcher, IAttackDispatcherTrait, maybe_create_attacks,
    };
}
pub mod amma_contract;
pub mod attributes;
pub use attributes::{Abilities, Attributes, AttributesTrait, PartialAttributes};
pub mod classic_contract;

pub mod interface;
pub use interface::get_loadout;

#[cfg(test)]
mod test {
    mod ability;
}
