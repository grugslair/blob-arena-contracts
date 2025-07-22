pub mod attack {
    pub mod types;
    pub use types::{Attack, AttackInput, Effect, EffectInput, get_attack_id};
    mod contract;
    pub mod interface;
}
pub mod ability;
pub mod dojo;
pub mod signed;
