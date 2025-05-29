use cubit::f128::types::fixed::Fixed;

const STARTING_HEALTH: u8 = 100;
const THREE_TENTHS_FIXED: Fixed = Fixed { mag: 5534023222112865484, sign: false };
const HUNDRED_FIXED: Fixed = Fixed { mag: 1844674407370955161600, sign: false };
const FIXED_255: Fixed = Fixed { mag: 4703919738795935662080, sign: false };
const HUNDREDTH_FIXED: Fixed = Fixed { mag: 184467440737095516, sign: false };
const NZ_255: NonZero<u128> = 255;
const NZ_100: NonZero<u128> = 100;
const MAX_STAT: u8 = 100;
const SECONDS_2_HOURS: u64 = 7200; // 2 hours
const SECONDS_8_HOURS: u64 = 28800; // 8 hours
const SECONDS_12_HOURS: u64 = 43200; // 12 hours
const SECONDS_24_HOURS: u64 = 86400; // 24 hours
