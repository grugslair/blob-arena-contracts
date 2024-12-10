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
    use components::{Item, ItemsTrait};
    use systems::{ItemTrait};
}
mod attacks {
    mod components;
    mod systems;
    mod contract;
    mod results;
    use components::{
        Stat, Target, Affect, Damage, Attack, Effect, PlannedAttack, PlannedAttacksTrait
    };
    use systems::{AttackTrait, AvailableAttackTrait, PlannedAttackTrait};
}
mod stats;
mod combatants {
    mod components;
    mod systems;
    use components::{
        CombatantInfo, CombatantState, CombatantInfoTrait, CombatantStateTrait, CombatantToken
    };
    use systems::CombatantTrait;
}
mod combat {
    mod calculations;
    mod components;
    mod systems;
    use components::{Phase, CombatState};
    use systems::CombatTrait;
}
mod game {
    mod components;
    mod contract;
    mod systems;
}

mod betsy {
    mod components;
    mod systems;
    mod contract;
}

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

