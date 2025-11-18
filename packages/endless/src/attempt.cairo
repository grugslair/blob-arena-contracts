use ba_loadout::Attributes;
use ba_utils::BoolIntoU8;
use sai_packing::shifts::{SHIFT_12B, SHIFT_8B};
use sai_packing::{MaskDowncast, ShiftCast};
use starknet::ContractAddress;
use starknet::storage::{Map, Mutable, StoragePath};
use starknet::storage_access::StorePacking;

pub type AttemptNodePath = StoragePath<Mutable<AttemptNode>>;

#[starknet::storage_node]
pub struct AttemptNode {
    pub player: ContractAddress,
    pub attacks: [felt252; 4],
    pub attributes: Attributes,
    pub orb_used: Map<u32, bool>,
    pub stage: u32,
    pub info: AttemptInfo,
}

#[derive(Drop)]
pub struct AttemptInfo {
    pub expiry: u64,
    pub stage: u32,
    pub health: u8,
    pub respawned: bool,
}

#[generate_trait]
impl AttemptInfoImpl of AttemptInfoTrait {
    fn new(expiry: u64) -> AttemptInfo {
        AttemptInfo { stage: 0, respawned: false, expiry, health: 0 }
    }
}

#[generate_trait]
impl AttemptNodeImpl of AttemptNodeTrait {}

impl AttemptInfoStorePacking of StorePacking<AttemptInfo, u128> {
    fn pack(value: AttemptInfo) -> u128 {
        value.expiry.into()
            + ShiftCast::const_cast::<SHIFT_8B>(value.stage)
            + ShiftCast::const_cast::<SHIFT_12B>(value.health)
            + ShiftCast::<u8>::const_cast::<SHIFT_12B>(value.respawned.into())
    }
    fn unpack(value: u128) -> AttemptInfo {
        AttemptInfo {
            expiry: MaskDowncast::cast(value),
            stage: ShiftCast::const_unpack::<SHIFT_8B>(value),
            health: ShiftCast::const_unpack::<SHIFT_12B>(value),
            respawned: ShiftCast::<u8>::const_unpack::<SHIFT_12B>(value) != 0_u8,
        }
    }
}
