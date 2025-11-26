use ba_combat::combatant::CombatantState;
use ba_loadout::Attributes;
use ba_utils::BoolIntoU8;
use sai_packing::shifts::{SHIFT_12B, SHIFT_13B, SHIFT_4B, SHIFT_8B};
use sai_packing::{MaskDowncast, ShiftCast};
use starknet::ContractAddress;
use starknet::storage::{Map, Mutable, StoragePath};
use starknet::storage_access::StorePacking;

pub type AttemptNodePath = StoragePath<Mutable<AttemptNode>>;

#[derive(Drop, Copy, Introspect, PartialEq, Serde)]
pub enum EndlessProgress {
    None,
    Active,
    Ended,
}

impl EndlessProgressIntoU8 of Into<EndlessProgress, u8> {
    fn into(self: EndlessProgress) -> u8 {
        match self {
            EndlessProgress::None => 0,
            EndlessProgress::Active => 1,
            EndlessProgress::Ended => 2,
        }
    }
}

impl U8IntoEndlessProgress of Into<u8, EndlessProgress> {
    fn into(self: u8) -> EndlessProgress {
        match self {
            0 => EndlessProgress::None,
            1 => EndlessProgress::Active,
            2 => EndlessProgress::Ended,
            _ => panic!("Invalid value for EndlessProgress"),
        }
    }
}

#[derive(Drop)]
pub struct AttemptInfo {
    pub expiry: u64,
    pub stage: u32,
    pub respawns: u8,
    pub progress: EndlessProgress,
}

#[generate_trait]
pub impl AttemptInfoImpl of AttemptInfoTrait {
    fn new(expiry: u64) -> AttemptInfo {
        AttemptInfo { stage: 0, expiry, respawns: 0, progress: EndlessProgress::Active }
    }
}

impl AttemptInfoStorePacking of StorePacking<AttemptInfo, u128> {
    fn pack(value: AttemptInfo) -> u128 {
        value.expiry.into()
            + ShiftCast::const_cast::<SHIFT_8B>(value.stage)
            + ShiftCast::const_cast::<SHIFT_12B>(value.respawns)
            + ShiftCast::<u8>::const_cast::<SHIFT_13B>(value.progress.into())
    }
    fn unpack(value: u128) -> AttemptInfo {
        AttemptInfo {
            expiry: MaskDowncast::cast(value),
            stage: ShiftCast::const_unpack::<SHIFT_8B>(value),
            respawns: ShiftCast::const_unpack::<SHIFT_12B>(value),
            progress: ShiftCast::<u8>::const_unpack::<SHIFT_13B>(value).into(),
        }
    }
}

#[starknet::storage_node]
pub struct AttemptNode {
    pub player: ContractAddress,
    pub attacks: [felt252; 4],
    pub attributes: Attributes,
    pub orb_used: Map<u32, bool>,
    pub info: AttemptInfo,
    pub combats: Map<u32, CombatNode>,
    pub actions_available: Map<felt252, bool>,
    pub opponent_attributes: Map<u32, Attributes>,
}


#[derive(Drop, Copy, Introspect, PartialEq, Serde)]
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
    pub n_opponent_actions: u32,
    pub phase: CombatProgress,
}


impl CombatInfoStorePacking of StorePacking<CombatInfo, u128> {
    fn pack(value: CombatInfo) -> u128 {
        value.round.into()
            + ShiftCast::const_cast::<SHIFT_4B>(value.n_opponent_actions)
            + ShiftCast::<u8>::const_cast::<SHIFT_8B>(value.phase.into())
    }
    fn unpack(value: u128) -> CombatInfo {
        CombatInfo {
            round: MaskDowncast::cast(value),
            n_opponent_actions: ShiftCast::const_unpack::<SHIFT_4B>(value),
            phase: ShiftCast::<u8>::const_unpack::<SHIFT_8B>(value).into(),
        }
    }
}


#[starknet::storage_node]
pub struct CombatNode {
    pub player_state: CombatantState,
    pub opponent_state: CombatantState,
    pub action_last_used: Map<felt252, u32>,
    pub opponent_actions: Map<u32, (felt252, u32)>,
    pub info: CombatInfo,
}

