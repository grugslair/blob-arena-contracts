mod core;
mod constants;
mod utils;
mod id_trait;
mod ab;
mod salts;
mod commitments;
mod collections;
mod hash;
mod world;
mod storage;
mod serde;
use world::uuid;
// mod permissions {
//     mod components;
//     mod systems;
//     mod contract;
//     use components::{Permissions, WritePermissions};
// }
// use permissions::Permissions;
mod attacks {
    mod components;
    // mod contract;
    mod results;
    mod storage;
    use components::{
        Stat, Target, Affect, Damage, Attack, Effect, PlannedAttack, AvailableAttackTrait,
    };
    use storage::AttackStorage;
}
mod stats;
mod combatants {
    mod components;
    mod systems;
    mod storage;
    use components::{
        CombatantInfo, CombatantState, CombatantInfoTrait, CombatantStateTrait, CombatantToken
    };
    use storage::CombatantStorage;
    use systems::CombatantTrait;
}
mod combat {
    mod calculations;
    mod components;
    mod systems;
    mod storage;
    use components::{Phase, CombatState};
    use systems::CombatTrait;
    use storage::CombatStorage;
}
mod game {
    mod components;
    mod storage;
    mod contract;
    mod systems;
    use storage::GameStorage;
    mod admin;
}

mod lobby {
    mod components;
    mod storage;
    mod systems;
    mod contract;
}

pub use world::{default_namespace, DefaultStorage};
#[cfg(test)]
mod tests {
    // mod pvp_test;
    mod core_test;
    mod combat_test;
    mod utils_test;
    mod attack_test;
}

