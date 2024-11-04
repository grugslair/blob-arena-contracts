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
use world::uuid;
mod permissions {
    mod components;
    mod systems;
    mod contract;
}
use permissions::components::Permissions;
mod items {
    mod components;
    mod systems;
    use components::{Item, ItemsTrait};
    use systems::{ItemTrait};
}
mod attacks {
    mod components;
    mod systems;
    mod contract;
    mod results;
    use components::{Stat, Target, Affect, Damage, Attack, Effect};
    use systems::{AttackTrait, AvailableAttackTrait};
}
mod stats;
mod combatants {
    mod components;
    mod systems;
    use components::{CombatantInfo, CombatantState, CombatantInfoTrait, CombatantStateTrait};
    use systems::CombatantTrait;
}
mod combat {
    mod calculations;
    mod components;
    mod systems;
}
mod pvp {
    mod components;
    // mod systems;
// mod contract;
}
// mod world;

// #[cfg(test)]
// mod tests {
//     // mod pvp_test;
//     mod core_test;
//     mod combat_test;
//     mod utils_test;
// }


