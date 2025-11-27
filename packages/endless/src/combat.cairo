use ba_combat::combatant::CombatantState;
use ba_utils::BoolIntoU8;
use sai_packing::shifts::{SHIFT_4B, SHIFT_8B};
use sai_packing::{MaskDowncast, ShiftCast};
use starknet::storage::{Map, Mutable, StoragePath};
use starknet::storage_access::StorePacking;

pub type CombatNodePath = StoragePath<Mutable<CombatNode>>;

#[derive(Drop, Copy, Introspect, PartialEq, Serde, Default, starknet::Store)]
pub enum CombatProgress {
    #[default]
    None,
    Active,
    PlayerWon,
    PlayerLost,
}


impl CombatProgressIntoU8 of Into<CombatProgress, u8> {
    fn into(self: CombatProgress) -> u8 {
        match self {
            CombatProgress::None => 0,
            CombatProgress::Active => 1,
            CombatProgress::PlayerWon => 2,
            CombatProgress::PlayerLost => 3,
        }
    }
}


impl U8IntoCombatProgress of Into<u8, CombatProgress> {
    fn into(self: u8) -> CombatProgress {
        match self {
            0 => CombatProgress::None,
            1 => CombatProgress::Active,
            2 => CombatProgress::PlayerWon,
            3 => CombatProgress::PlayerLost,
            _ => panic!("Invalid value for CombatProgress"),
        }
    }
}

#[derive(Drop)]
pub struct CombatInfo {
    pub round: u32,
    pub phase: CombatProgress,
}


#[generate_trait]
pub impl CombatInfoImpl of CombatInfoTrait {
    fn new() -> CombatInfo {
        CombatInfo { round: 1, phase: CombatProgress::Active }
    }
}

impl CombatInfoStorePacking of StorePacking<CombatInfo, u64> {
    fn pack(value: CombatInfo) -> u64 {
        value.round.into() + ShiftCast::<u8>::const_cast::<SHIFT_4B>(value.phase.into())
    }
    fn unpack(value: u64) -> CombatInfo {
        CombatInfo {
            round: MaskDowncast::cast(value),
            phase: ShiftCast::<u8>::const_unpack::<SHIFT_4B>(value).into(),
        }
    }
}


#[starknet::storage_node]
pub struct CombatNode {
    pub player_state: CombatantState,
    pub opponent_state: CombatantState,
    pub player_last_used: Map<felt252, u32>,
    pub opponent_last_used: Map<felt252, u32>,
    pub round: u32,
}
