use ba_loadout::attack::Affect;
use ba_loadout::attack::effect::unpack_affect;
use ba_utils::storage::{read_at_base_offset, read_at_felt252, write_at_base_offset};
use core::dict::Felt252Dict;
use core::nullable::{FromNullableResult, match_nullable};
use core::num::traits::DivRem;
use sai_core_utils::poseidon_hash_two;
use sai_packing::shifts::{SHIFT_18B_FELT252, SHIFT_1B_FELT252, SHIFT_2B};
use sai_packing::{BShiftCast, GetShift, MaskDowncast, ShiftCast};
use starknet::storage_access::{StorageBaseAddress, StorePacking, storage_base_address_from_felt252};
use crate::Player;


const PLAYER_2_ATTACKER_PACKING_BITS: felt252 = SHIFT_18B_FELT252;
const PLAYER_2_DEFENDER_PACKING_BITS: felt252 = SHIFT_18B_FELT252 * 2;

const SHIFT_2B_NZ_U256: NonZero<u256> = 0x100;
const SHIFT_1B_NZ_U16: NonZero<u16> = 0x100;

#[derive(Drop)]
struct RoundEffect {
    pub attacker: Player,
    pub defender: Player,
    pub affect: Affect,
}


impl RoundEffectStorePacking of StorePacking<RoundEffect, felt252> {
    fn pack(value: RoundEffect) -> felt252 {
        StorePacking::pack(value.affect)
            + match value.attacker {
                Player::Player1 => 0,
                Player::Player2 => PLAYER_2_ATTACKER_PACKING_BITS,
            }
            + match value.defender {
                Player::Player1 => 0,
                Player::Player2 => PLAYER_2_DEFENDER_PACKING_BITS,
            }
    }
    fn unpack(value: felt252) -> RoundEffect {
        let u256 { low, high } = value.into();
        let variant: u16 = MaskDowncast::cast(high);
        let (attacker, defender) = match ShiftCast::const_unpack::<SHIFT_2B>(high) {
            0_u8 => (Player::Player1, Player::Player1),
            1_u8 => (Player::Player2, Player::Player1),
            2_u8 => (Player::Player1, Player::Player2),
            3_u8 => (Player::Player2, Player::Player2),
            _ => panic!("Invalid value for Target"),
        };

        RoundEffect { attacker, defender, affect: unpack_affect(variant, low) }
    }
}

#[derive(PanicDestruct)]
pub struct RoundEffects {
    pub base_hash: felt252,
    pub round: u32,
    pub this_round_hash: StorageBaseAddress,
    pub inf_round_hash: StorageBaseAddress,
    pub this_count: u8,
    pub inf_count: u8,
    pub effect_counts: felt252,
    pub round_hashes: Felt252Dict<Nullable<StorageBaseAddress>>,
}

#[derive(Drop)]
struct RoundEffectsIterator {
    effects: @RoundEffects,
    index: u8,
    on_infs: bool,
}

impl RoundEffectsIteratorImpl of Iterator<RoundEffectsIterator> {
    type Item = RoundEffect;
    fn next(ref self: RoundEffectsIterator) -> Option<Self::Item> {
        if !self.on_infs {
            if self.index < *self.effects.this_count {
                let effect = self.effects.get_affect(self.index);
                self.index += 1;
                return Some(effect);
            }
            self.index = 0;
            self.on_infs = true;
        }
        if self.index < *self.effects.inf_count {
            let effect = self.effects.get_inf_affect(self.index);
            self.index += 1;
            Some(effect)
        } else {
            None
        }
    }
}

impl RoundEffectsIntoIter of IntoIterator<@RoundEffects> {
    type IntoIter = RoundEffectsIterator;
    fn into_iter(self: @RoundEffects) -> Self::IntoIter {
        RoundEffectsIterator { effects: self, index: 0, on_infs: false }
    }
}

#[generate_trait]
pub impl RoundEffectImpl of RoundEffectsTrait {
    fn new(combat_id: felt252, round: u32) -> RoundEffects {
        let base_hash = poseidon_hash_two(combat_id, selector!("round_effects"));
        let this_round_hash = storage_base_address_from_felt252(
            poseidon_hash_two(base_hash, round),
        );
        let inf_round_hash = storage_base_address_from_felt252(poseidon_hash_two(base_hash, 0));
        let effects_count: u256 = read_at_felt252(base_hash).into();
        let (effects, other) = effects_count.div_rem(SHIFT_2B_NZ_U256);
        let (this_count, inf_count): (u16, u16) = DivRem::<
            u16,
        >::div_rem(other.try_into().unwrap(), SHIFT_1B_NZ_U16);
        let effect_counts = effects.try_into().unwrap() * SHIFT_1B_FELT252 + inf_count.into();

        RoundEffects {
            base_hash,
            round,
            inf_count: inf_count.try_into().unwrap(),
            this_count: this_count.try_into().unwrap(),
            round_hashes: Default::default(),
            this_round_hash,
            inf_round_hash,
            effect_counts,
        }
    }
    fn get_inf_affect(self: @RoundEffects, index: u8) -> RoundEffect {
        StorePacking::unpack(read_at_base_offset(*self.inf_round_hash, index))
    }
    fn get_affect(self: @RoundEffects, index: u8) -> RoundEffect {
        StorePacking::unpack(read_at_base_offset(*self.this_round_hash, index))
    }

    fn add_effect(ref self: RoundEffects, effect: RoundEffect, mut round: u32) {
        if round > 30 {
            round = 30;
        }
        let round_u8: u8 = round.try_into().unwrap();
        let round_felt252: felt252 = round.into();
        let round_hash = match match_nullable(self.round_hashes.get(round_felt252)) {
            FromNullableResult::Null => {
                let hash = storage_base_address_from_felt252(
                    poseidon_hash_two(self.base_hash, round + self.round),
                );
                self.round_hashes.insert(round_felt252, NullableTrait::new(hash));
                hash
            },
            FromNullableResult::NotNull(value) => value.unbox(),
        };

        let effect_count: u8 = BShiftCast::unpack(self.effect_counts, round_u8);
        if effect_count < 255 {
            self.effect_counts += GetShift::get_shift(round_u8);
            write_at_base_offset(round_hash, effect_count, StorePacking::pack(effect))
        }
    }

    fn add_infinite_effect(ref self: RoundEffects, effect: RoundEffect) {
        if self.inf_count < 255 {
            self.inf_count += 1;
            self.effect_counts += SHIFT_1B_FELT252;

            write_at_base_offset(self.inf_round_hash, self.inf_count, StorePacking::pack(effect));
        }
    }
    fn clear(ref self: RoundEffects) {
        self.effect_counts = 0;
    }
}
