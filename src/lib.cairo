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
mod starknet;
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
    use components::{
        Stat, Target, Affect, Damage, Attack, Effect, PlannedAttack, AttackInput, AttackInputTrait,
    };
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
    use components::{Phase, CombatState, AttackCooledDown, CombatProgress};
    use systems::CombatTrait;
    use storage::CombatStorage;
}
mod pvp {
    mod components;
    mod storage;
    mod contract;
    mod systems;
    use storage::GameStorage;
    use systems::GameTrait;
}

mod lobby {
    mod components;
    mod storage;
    mod systems;
    mod contract;
}

mod arcade {
    mod components;
    mod systems;
    mod contract;
    use systems::ArcadeTrait;
    use components::{
        ArcadeGame, ArcadeOpponent, ArcadeBlobertInfo, ArcadeStorage, ArcadePhase, ArcadeStore,
        ArcadeChallengeAttempt, ArcadePhaseTrait, ArcadeAttemptEnd, ArcadeOpponentInput,
        ARCADE_NAMESPACE_HASH, ARCADE_CHALLENGE_MAX_RESPAWNS, CHALLENGE_TAG_GROUP,
        ARCADE_CHALLENGE_GAME_ENERGY_COST, ARCADE_CHALLENGE_MAX_ENERGY,
    };
}

mod achievements {
    mod components;
    mod systems;
    use components::{TaskId, AchievementsEvents, ACHIEVEMENTS_NAMESPACE_HASH, TrophyCreationInput};
    use systems::Achievements;
}

mod game {
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

