use ba_loadout::Attributes;
use ba_utils::BoolIntoU8;
use ba_utils::storage::{FeltArrayReadWrite, ShortArrayStore};
use sai_packing::shifts::{SHIFT_10B, SHIFT_12B, SHIFT_8B};
use sai_packing::{MaskDowncast, ShiftCast};
use starknet::storage::{Map, Mutable, StoragePath, StoragePointerReadAccess};
use starknet::storage_access::StorePacking;
use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
use crate::combat::CombatNode;

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
    pub stage: u16,
    pub respawns: u16,
    pub progress: EndlessProgress,
}

#[generate_trait]
pub impl AttemptInfoImpl of AttemptInfoTrait {
    fn new(expiry: u64) -> AttemptInfo {
        AttemptInfo { stage: 0, expiry, respawns: 0, progress: EndlessProgress::Active }
    }
    fn assert_not_expired(self: @AttemptInfo) {
        assert(get_block_timestamp() <= *self.expiry, 'Attempt has expired');
    }
    fn combat(self: @AttemptInfo) -> u16 {
        *self.stage + (*self.respawns)
    }
}

impl AttemptInfoStorePacking of StorePacking<AttemptInfo, u128> {
    fn pack(value: AttemptInfo) -> u128 {
        value.expiry.into()
            + ShiftCast::const_cast::<SHIFT_8B>(value.stage)
            + ShiftCast::const_cast::<SHIFT_10B>(value.respawns)
            + ShiftCast::<u8>::const_cast::<SHIFT_12B>(value.progress.into())
    }
    fn unpack(value: u128) -> AttemptInfo {
        AttemptInfo {
            expiry: MaskDowncast::cast(value),
            stage: ShiftCast::const_unpack::<SHIFT_8B>(value),
            respawns: ShiftCast::const_unpack::<SHIFT_10B>(value),
            progress: ShiftCast::<u8>::const_unpack::<SHIFT_12B>(value).into(),
        }
    }
}

#[starknet::storage_node]
pub struct AttemptNode {
    pub player: ContractAddress,
    pub attacks: Map<felt252, u32>,
    pub attributes: Attributes,
    pub orb_used: Map<u16, bool>,
    pub info: AttemptInfo,
    pub combats: Map<u16, CombatNode>,
    pub actions_available: Map<felt252, bool>,
    pub opponent_attributes: Map<u16, Attributes>,
    pub opponent_attacks: Map<u16, Array<felt252>>,
}


#[generate_trait]
pub impl AttemptNodeImpl of AttemptNodeTrait {
    fn assert_caller_is_owner(self: AttemptNodePath) -> ContractAddress {
        let caller = get_caller_address();
        assert(self.player.read() == caller, 'Not Callers Game');
        caller
    }
}
