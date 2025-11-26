use ba_loadout::Attributes;
use sai_packing::shifts::{SHIFT_4B, SHIFT_8B};
use sai_packing::{MaskDowncast, ShiftCast};
use starknet::ContractAddress;
use starknet::storage::Map;
use starknet::storage_access::StorePacking;


#[starknet::contract]
mod endless_contract {
    #[storage]
    struct Storage {
        current_season: u64,
        season_length: u64,
    }
}
