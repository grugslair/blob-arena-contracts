use ba_utils::{Randomness, RandomnessTrait};
use core::cmp::min;
use sai_packing::shifts::{
    SHIFT_10B, SHIFT_12B, SHIFT_16B, SHIFT_16B_FELT252, SHIFT_18B, SHIFT_20B_FELT252,
    SHIFT_22B_FELT252, SHIFT_24B, SHIFT_24B_FELT252, SHIFT_26B, SHIFT_26B_FELT252, SHIFT_28B,
    SHIFT_28B_FELT252, SHIFT_2B, SHIFT_4B, SHIFT_8B,
};
use sai_packing::{BytePacking, MaskDowncast, ShiftCast};
use starknet::storage::{
    Map, Mutable, MutableVecTrait, StorageMapReadAccess, StorageMapWriteAccess, StoragePath,
    StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Vec,
};
use starknet::storage_access::StorePacking;
use starknet::{ContractAddress, get_block_timestamp};
use crate::attempt::{AttemptInfo, AttemptInfoTrait, AttemptNode};

pub type SeasonNodePath = StoragePath<Mutable<SeasonNode>>;

#[derive(Drop)]
pub struct HealthRegen {
    pub min_percent: u8,
    pub max_percent: u8,
}

#[starknet::storage_node]
pub struct SeasonNode {
    pub times: Times,
    pub n_attempts: u64,
    pub attempts: Map<u64, AttemptNode>,
    pub jackpot: u256,
    pub claimed: Map<u8, bool>,
    pub winners: Winners,
    pub jackpot_splits: JackpotSplits,
    pub fees: Fees,
    pub max_respawns: u16,
    pub health_regen: HealthRegen,
}


#[derive(Drop)]
struct Fees {
    pub team_ppm: u16,
    pub vlords_ppm: u16,
}

#[derive(Drop)]
struct Winners {
    pub first_attempt: u64,
    pub second_attempt: u64,
    pub third_attempt: u64,
    pub first_stage: u16,
    pub second_stage: u16,
    pub third_stage: u16,
}

#[derive(Drop)]
pub struct JackpotSplits {
    pub first: u32,
    pub second: u32,
    pub third: u32,
}

#[derive(Drop)]
struct Times {
    pub start: u64,
    pub end: u64,
    pub limit: u64,
}

#[generate_trait]
pub impl SeasonImpl of SeasonTrait {
    fn submit_attempt(self: SeasonNodePath, id: u64, stage: u16) {
        let mut winners = self.winners.read();
        if stage < winners.third_stage {
            return;
        } else if stage < winners.second_stage {
            if id == winners.third_attempt {
                return;
            }
            winners.third_attempt = id;
            winners.third_stage = stage;
        } else if stage < winners.first_stage {
            if id == winners.second_attempt {
                return;
            }
            winners.third_attempt = winners.second_attempt;
            winners.third_stage = winners.second_stage;
            winners.second_attempt = id;
            winners.second_stage = stage;
        } else {
            if id == winners.first_attempt {
                return;
            }
            winners.third_attempt = winners.second_attempt;
            winners.third_stage = winners.second_stage;
            winners.second_attempt = winners.first_attempt;
            winners.second_stage = winners.first_stage;
            winners.first_attempt = id;
            winners.first_stage = stage;
        }
        self.winners.write(winners);
    }

    fn init_attempt(ref self: SeasonNodePath, player: ContractAddress) -> u64 {
        let times = self.times.read();
        let timestamp = get_block_timestamp();
        assert(timestamp >= times.start, 'Season not started');
        assert(timestamp < times.end, 'Season ended');

        let attempt_id = self.n_attempts.read() + 1;
        self.n_attempts.write(attempt_id);
        let attempt_node = self.attempts.entry(attempt_id);
        attempt_node.player.write(player);
        attempt_node.info.write(AttemptInfoTrait::new(min(timestamp + times.limit, times.end)));
        attempt_id
    }


    fn assert_ended(self: @SeasonNodePath) {
        let times = self.times.read();
        assert(get_block_timestamp() >= times.end, 'Season not ended')
    }

    fn get_health_regen_percent(self: @SeasonNodePath, ref randomness: Randomness) -> u8 {
        let HealthRegen { min_percent, max_percent } = self.health_regen.read();
        randomness.get(max_percent - min_percent + 1) + min_percent
    }
}


impl FeesStorePacking of StorePacking<Fees, u32> {
    fn pack(value: Fees) -> u32 {
        value.team_ppm.into() + ShiftCast::const_cast::<SHIFT_2B>(value.vlords_ppm)
    }

    fn unpack(value: u32) -> Fees {
        Fees {
            team_ppm: MaskDowncast::cast(value),
            vlords_ppm: ShiftCast::const_unpack::<SHIFT_2B>(value),
        }
    }
}

impl TimesStorePacking of StorePacking<Times, felt252> {
    fn pack(value: Times) -> felt252 {
        value.start.into()
            + ShiftCast::const_cast::<SHIFT_8B>(value.end)
            + ShiftCast::const_cast::<SHIFT_16B_FELT252>(value.limit)
    }

    fn unpack(value: felt252) -> Times {
        let u256 { low, high } = value.into();
        Times {
            start: MaskDowncast::cast(low),
            end: ShiftCast::const_unpack::<SHIFT_8B>(low),
            limit: MaskDowncast::cast(high),
        }
    }
}

impl WinnersPacking of StorePacking<Winners, felt252> {
    fn pack(value: Winners) -> felt252 {
        value.first_attempt.into()
            + ShiftCast::const_cast::<SHIFT_8B>(value.second_attempt)
            + ShiftCast::const_cast::<SHIFT_16B_FELT252>(value.third_attempt)
            + ShiftCast::const_cast::<SHIFT_24B_FELT252>(value.first_stage)
            + ShiftCast::const_cast::<SHIFT_26B_FELT252>(value.second_stage)
            + ShiftCast::const_cast::<SHIFT_28B_FELT252>(value.third_stage)
    }

    fn unpack(value: felt252) -> Winners {
        let u256 { low, high } = value.into();
        Winners {
            first_attempt: MaskDowncast::cast(low),
            second_attempt: ShiftCast::const_unpack::<SHIFT_12B>(low),
            third_attempt: MaskDowncast::cast(high),
            second_stage: ShiftCast::const_unpack::<SHIFT_8B>(high),
            third_stage: ShiftCast::const_unpack::<SHIFT_10B>(high),
            first_stage: ShiftCast::const_unpack::<SHIFT_12B>(high),
        }
    }
}

impl JackpotSplitsPacking of StorePacking<JackpotSplits, u128> {
    fn pack(value: JackpotSplits) -> u128 {
        value.first.into()
            + ShiftCast::const_cast::<SHIFT_4B>(value.second)
            + ShiftCast::const_cast::<SHIFT_8B>(value.third)
    }

    fn unpack(value: u128) -> JackpotSplits {
        JackpotSplits {
            first: MaskDowncast::cast(value),
            second: ShiftCast::const_unpack::<SHIFT_4B>(value),
            third: ShiftCast::const_unpack::<SHIFT_8B>(value),
        }
    }
}

impl HealthRegenStorePacking of StorePacking<HealthRegen, u16> {
    fn pack(value: HealthRegen) -> u16 {
        BytePacking::pack([value.min_percent, value.max_percent])
    }

    fn unpack(value: u16) -> HealthRegen {
        let [min_percent, max_percent] = BytePacking::unpack(value);
        HealthRegen { min_percent, max_percent }
    }
}

