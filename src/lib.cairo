mod core;
mod constants;
mod utils;
mod id_trait;
mod commitments;
mod collections;
mod hash;
mod world;
mod storage;
mod serde;
mod iter;
mod tags;
mod erc721;
use world::uuid;
mod permissions {
    mod components;
    mod systems;
    use components::{PermissionStorage, Role, Permission};
    use systems::Permissions;
}
mod attacks {
    mod components;
    mod results;
    mod storage;
    mod systems;
    use components::{Stat, Target, Affect, Damage, Attack, Effect, PlannedAttack, AttackInput};
    use storage::AttackStorage;
    use systems::AttackTrait;
}
mod stats;
mod combatants {
    mod components;
    mod systems;
    use components::{
        CombatantInfo, CombatantState, CombatantInfoTrait, CombatantStateTrait, CombatantToken,
        CombatantStorage, CombatantSetup,
    };
    use systems::CombatantTrait;
}
mod combat {
    mod calculations;
    mod components;
    mod systems;
    mod storage;
    use components::{Phase, CombatState, AttackCooledDown};
    use systems::CombatTrait;
    use storage::CombatStorage;
}
mod game {
    mod components;
    mod storage;
    mod contract;
    mod systems;
    use components::{GameProgress};
    use storage::GameStorage;
    use systems::GameTrait;
    mod admin;
}

mod lobby {
    mod components;
    mod storage;
    mod systems;
    mod contract;
}

mod pve {
    mod components;
    mod systems;
    mod contract;
    mod admin;
    use systems::PVETrait;
    use components::{
        PVEGame, PVEOpponent, PVEBlobertInfo, PVEStorage, PVEPhase, PVEStore, PVEChallengeAttempt,
        PVEPhaseTrait, PVEAttemptEnd, PVEOpponentInput, PVE_NAMESPACE_HASH,
        ARCADE_CHALLENGE_MAX_RESPAWNS,
    };
}

mod achievements;

pub use world::{default_namespace, DefaultStorage};
#[cfg(test)]
mod tests {
    // mod pvp_test;
    mod core_test;
    mod combat_test;
    mod utils_test;
    mod attack_test;
}

