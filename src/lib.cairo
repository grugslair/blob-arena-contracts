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
mod items {
    mod components;
    mod systems;
    mod storage;
    use components::Item;
    use systems::ItemTrait;
    use storage::ItemStorage;
}
mod attacks {
    mod components;
    mod contract;
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
}

// mod lobby {
//     mod components;
//     mod systems;
//     mod contract;
// }

// mod pvp {
//     mod components;
//     mod systems;
//     mod contract;
//     use components::{
//         PvPChallenge, PvPCombatants, PvPChallengeScore, PvPChallengeTrait, PvPChallengeInvite,
//         PvPChallengeResponse, make_pvp_challenge, PvPChallengeScoreTrait
//     };
//     use systems::{PvPTrait, PvPCombatTrait};
// }
use world::default_namespace;
#[cfg(test)]
mod tests {
    // mod pvp_test;
    mod core_test;
    mod combat_test;
    mod utils_test;
    mod attack_test;
}

