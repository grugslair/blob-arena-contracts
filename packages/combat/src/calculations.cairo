use ba_utils::{CapInto, Randomness, RandomnessTrait};
use core::num::traits::{WideMul, Zero};
use cubit::f128::types::fixed::{Fixed, FixedTrait};
use sai_core_utils::SaturatingInto;

const HUNDRED_FIXED: Fixed = Fixed { mag: 1844674407370955161600, sign: false };
const FIXED_255: Fixed = Fixed { mag: 4703919738795935662080, sign: false };
const RESISTANCE_SCALE: u32 = 1_000_000;
/// Applies a luck modifier to a given value, transforming it based on the luck parameter.
/// The function uses a mathematical formula to adjust the value based on the luck ratio.
///
/// # Arguments
///
/// * `value` - An u8 value to be modified (0-100)
/// * `luck` - An u8 value representing luck factor (0-100)
///
/// # Returns
///
/// * a value scaled between 0 and 225
///
/// #
///
///                    value   ^  luck_ratio
/// equivalent to  (0.0 - 1.0) ^ (0.66 to 1.5)
/// as luck increases, the value is more likely to be closer to 1.0
/// the return value is the probability of something scaled between 0 and 255
///
/// # Note
///
/// If the input value is 0, the function returns zero regardless of luck value.
/// If the calculated new value exceeds 255, it is capped at 255.Testing. Testing.

pub fn apply_luck_modifier<T, +TryInto<Fixed, T>, +Into<u8, T>, +Zero<T>>(
    value: u8, luck: u8,
) -> T {
    if value == 0 {
        return Zero::zero();
    }
    let luck: u16 = luck.into();
    let luck_ratio: Fixed = (300_u16 - luck).into() / (200_u16 + luck).into();
    let value_float = value.into() / HUNDRED_FIXED;
    let new_value = (value_float.pow(luck_ratio) * FIXED_255);
    if new_value > FIXED_255 {
        255_u8.into()
    } else {
        new_value.try_into().unwrap()
    }
}

pub fn increase_resistance(value: u8, change: u8) -> u8 {
    if change.is_zero() {
        return value;
    }
    if change == 100 || value == 100 {
        return 100;
    }
    let change: u16 = change.into();
    let value: u16 = value.into();
    (((value + change) * 100 - value * change) / 100).cap_into(100)
}

pub fn get_new_stun_chance(current_stun: u8, action_stun: u8) -> u8 {
    (current_stun.into()
        + action_stun.into()
        - (current_stun.into() * action_stun.into() / 100_u16))
        .saturating_into()
}

pub fn combine_resistance(
    value: u32 , change: u32,
) -> u32 {
    value.into() * change.into() / 1_000
    
}

/// Calculates the damage dealt by an action based on move power, strength, and critical hit status
/// # Arguments
/// * `move_power` - The base power of the move being used (0-100)
/// * `strength` - The strength stat of the actor (0-100)
/// * `critical` - Whether the action is a critical hit
/// # Returns
/// The calculated damage as a u8 between 0 and 101 (202 if critical)

pub fn damage_calculation(move_power: u8, strength: u8, critical: bool) -> u16 {
    (move_power.wide_mul(100 + strength) / match critical {
        true => 50,
        false => 100,
    })
}

pub fn did_critical(chance: u8, luck: u8, ref randomness: Randomness) -> bool {
    randomness.get(255) < apply_luck_modifier::<u16>(chance, luck)
}
