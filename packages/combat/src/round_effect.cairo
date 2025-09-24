use ba_loadout::attack::Affect;
use ba_utils::storage::{read_at_base_offset, read_at_felt252};
use core::dict::{Felt252Dict, SquashedFelt252Dict};
use core::num::traits::Zero;
use core::traits::DivRem;
use sai_core_utils::poseidon_hash_two;
use sai_packing::{MaskDowncast, ShiftCast};
use starknet::storage_access::{StorageBaseAddress, storage_base_address_from_felt252};
use crate::Player;


const SHIFT_1B_NZ: NonZero<u256> = 0x100;

#[derive(Drop)]
struct RoundEffect {
    target: Player,
    affect: Affect,
}

#[derive(PanicDestruct)]
struct RoundEffects {
    base_hash: felt252,
    round: u32,
    this_round_hash: StorageBaseAddress,
    effects_count: felt252,
    round_hashes: Felt252Dict<felt252>,
}


#[generate_trait]
impl RoundsEffectImpl of RoundEffectsTrait {
    fn new(combat_id: felt252, round: u32) -> (RoundEffects, u8) {
        let base_hash = poseidon_hash_two(combat_id, selector!("round_effects"));
        let this_round_hash = storage_base_address_from_felt252(
            poseidon_hash_two(base_hash, round),
        );
        let effects_count: u256 = read_at_felt252(base_hash).into();
        let (effects, next) = DivRem::div_rem(effects_count, SHIFT_1B_NZ);
        (
            RoundEffects {
                base_hash,
                round,
                round_hashes: Default::default(),
                this_round_hash,
                effects_count: effects.try_into().unwrap(),
            },
            next.try_into().unwrap(),
        )
    }

    fn get_affect(self: @RoundEffects, index: u8) -> RoundEffect {
        read_at_base_offset(*self.this_round_hash, index)
    }

    fn add_effect(ref self: RoundEffects, effect: RoundEffect, round: u32) {
        let mut round_hash = self.round_hashes.get(round.into());
        if round_hash.is_zero() {
            round_hash = poseidon_hash_two(self.base_hash, round);
            self.round_hashes.insert(round.into(), round_hash);
        }

        let effect_count = ShiftCast::unpack::<SHI>(self.effects_count);
    }
}
