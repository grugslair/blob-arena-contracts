pub mod attack {
    pub mod types;
    pub use types::{
        Attack, AttackInput, AttackWithName, AttackWithNameTrait, Effect, EffectInput,
        get_attack_id,
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
pub mod interface;
pub mod signed;
