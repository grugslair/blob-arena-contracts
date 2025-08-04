use ba_loadout::ability::Abilities;
use ba_utils::{SeedProbability, felt252_to_u128};
use core::cmp::min;
use core::dict::Felt252Dict;

fn random_selection(seed: felt252, range: u32, number: u32) -> Array<u32> {
    assert(number <= range, 'Number must be <= to range');
    let mut seed = felt252_to_u128(seed);
    let mut values: Array<u32> = Default::default();
    let mut dict: Felt252Dict<u128> = Default::default();
    for n in 0..range {
        dict.insert(n.into(), n.into());
    }
    for i in 0_u128..min(number.into(), range.into() - 1) {
        let j: u128 = (i + seed.get_value((range.into() - i).try_into().unwrap()))
            .try_into()
            .unwrap();
        values.append(dict.get(j.into()).try_into().unwrap() + 1);
        dict.insert(j.into(), dict.get(i.into()));
    }
    if range == number {
        values.append(dict.get((range - 1).into()).try_into().unwrap() + 1);
    }
    values
}

fn get_stage_stats(stage: u32, fighter_stats: Abilities) -> Abilities {
    let stage_stats: Abilities = (5 * stage + 5).into();
    stage_stats + fighter_stats
}
