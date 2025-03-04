use core::num::traits::WideMul;
use cubit::f128::types::fixed::{FixedTrait, Fixed};
use blob_arena::{
    core::SaturatingInto, utils::SeedProbability, constants::{HUNDRED_FIXED, FIXED_255, NZ_255},
};

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
/// # Formula
///
///                    value   ^  luck_ratio
/// equivalent to  (0.0 - 1.0) ^ (0.66 to 1.5)
/// as luck increases, the value is more likely to be closer to 1.0
/// the return value is the probability of something scaled between 0 and 255
///
/// # Note
///
/// If the input value is 0, the function returns zero regardless of luck value.
/// If the calculated new value exceeds 255, it is capped at 255.

fn apply_luck_modifier<T, +TryInto<Fixed, T>, +Into<u8, T>, +Zeroable<T>>(
    value: u8, luck: u8,
) -> T {
    if value == 0 {
        return Zeroable::zero();
    };
    let luck_ratio: Fixed = (300_u16 - luck.into()).into() / (200_u16 + luck.into()).into();
    let value_float = value.into() / HUNDRED_FIXED;
    let new_value = (value_float.pow(luck_ratio) * FIXED_255);
    if new_value > FIXED_255 {
        255_u8.into()
    } else {
        new_value.try_into().unwrap()
    }
}


fn get_new_stun_chance(current_stun: u8, attack_stun: u8) -> u8 {
    (current_stun.into()
        + attack_stun.into()
        - (current_stun.into() * attack_stun.into() / 100_u16))
        .saturating_into()
}


/// Calculates the damage dealt by an attack based on move power, strength, and critical hit status
/// # Arguments
/// * `move_power` - The base power of the move being used (0-100)
/// * `strength` - The strength stat of the attacker (0-100)
/// * `critical` - Whether the attack is a critical hit
/// # Returns
/// The calculated damage as a u8 between 0 and 101 (202 if critical)

fn damage_calculation(move_power: u8, strength: u8, critical: bool) -> u8 {
    (move_power.wide_mul(100_u8 + strength) / match critical {
        true => 75,
        false => 150,
    })
        .saturating_into()
}

fn did_critical(chance: u8, luck: u8, ref seed: u128) -> bool {
    seed.get_outcome(NZ_255, apply_luck_modifier::<u128>(chance, luck))
}
