use core::{hash::HashStateTrait, poseidon::{PoseidonTrait, HashState},};
use blob_arena::{
    core::{SaturatingAdd, SaturatingSub},
    components::{
        combatant::{CombatantState, CombatantTrait}, attack::{Attack, AttackTrait},
        utils::{AB, ABT, ABTTrait}
    },
    utils::UpdateHashToU128, models::CombatantStateStore, systems::{combat::{CombatWorldTraits}},
    models::PlannedAttack,
};
use dojo::{world::{WorldStorage, ModelStorage}, model::Model};


#[generate_trait]
impl PvPCombatSystemImpl of PvPCombatTrait {}
