use cubit::f128::types::fixed::{FixedTrait, Fixed};
use blob_arena::{
    core::SaturatingInto, utils::SeedProbability, constants::{HUNDRED_FIXED, FIXED_255, NZ_255}
};

fn apply_luck_modifier<T, +TryInto<Fixed, T>, +Into<u8, T>, +Zeroable<T>>(
    value: u8, luck: u8
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

// power * (1 + 0.004 * strength)
fn damage_calculation(move_power: u8, strength: u8, critical: bool) -> u8 {
    (move_power.into() * (100 + strength.into()) / if critical {
        125_u128
    } else {
        250_u128
    })
        .saturating_into()
}

fn did_critical(chance: u8, luck: u8, ref seed: u128) -> bool {
    seed.get_outcome(NZ_255, apply_luck_modifier::<u128>(chance, luck))
}
