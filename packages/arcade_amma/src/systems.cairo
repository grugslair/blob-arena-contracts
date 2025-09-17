use ba_loadout::attributes::{Abilities, DAbilities};
use ba_utils::{Randomness, RandomnessTrait};
use core::cmp::min;
use core::dict::Felt252Dict;
use sai_core_utils::SaturatingInto;

pub fn random_selection(ref randomness: Randomness, range: u32, number: u32) -> Array<u32> {
    assert(number <= range, 'Number must be <= to range');

    let mut values: Array<u32> = Default::default();
    let mut dict: Felt252Dict<u32> = Default::default();
    for n in 0..range {
        dict.insert(n.into(), n.into());
    }
    for i in 0..min(number, range - 1) {
        let j = i + randomness.get(range - i);
        values.append(dict.get(j.into()) + 1);
        dict.insert(j.into(), dict.get(i.into()));
    }
    if range == number {
        values.append(dict.get((range - 1).into()) + 1);
    }
    values
}

pub fn get_stage_stats(stage: u32, fighter_stats: DAbilities) -> Abilities {
    ((5_i16 * stage.saturating_into() + 5).into() + fighter_stats).saturating_into()
}


pub fn attack_slots() -> Array<Array<felt252>> {
    array![array![0, 1, 2, 3]]
}


#[derive(Drop)]
struct Foo {}

pub trait BarTrait {
    fn call(self: Foo);
}

mod bar_impl {
    use super::{BarTrait, Foo};

    pub impl Bar<const HASH: felt252> of BarTrait {
        fn call(self: Foo) { // Do stuff.
            let _x = HASH + 1;
        }
    }
}
const HASH: felt252 = 42;
pub impl BarImpl = bar_impl::Bar<HASH>;


fn something_else() {
    Foo {}.call();
}

