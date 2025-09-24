use ba_loadout::attack::Affect;
use ba_loadout::attack::effect::unpack_affect;
use ba_utils::storage::{read_at_base_offset, read_at_felt252, write_at_base_offset};
use core::dict::Felt252Dict;
use core::nullable::{FromNullableResult, match_nullable};
use core::num::traits::Zero;
use core::traits::DivRem;
use sai_core_utils::poseidon_hash_two;
use sai_packing::masks::MASK_1B_U256;
use sai_packing::shifts::{SHIFTS_FELT252, SHIFTS_U256, SHIFT_18B_FELT252, SHIFT_2B};
use sai_packing::{BShiftCast, GetShift, MaskDowncast, ShiftCast};
use starknet::storage_access::{
    StorageBaseAddress, StorePacking, storage_base_address_const, storage_base_address_from_felt252,
};
use crate::Player;


impl Felt252StorageBaseAddressDictValue of Felt252DictValue<StorageBaseAddress> {
    fn zero_default() -> StorageBaseAddress nopanic {
        storage_base_address_const::<0>()
    }
}

impl StorageBaseAddressDefault of Default<StorageBaseAddress> {
    fn default() -> StorageBaseAddress nopanic {
        storage_base_address_const::<0>()
    }
}

const PLAYER_1_PACKING_BITS: felt252 = 0;
const PLAYER_2_PACKING_BITS: felt252 = SHIFT_18B_FELT252;

const SHIFT_1B_NZ: NonZero<u256> = 0x100;

#[derive(Drop)]
struct RoundEffect {
    target: Player,
    affect: Affect,
}


impl RoundEffectStorePacking of StorePacking<RoundEffect, felt252> {
    fn pack(value: RoundEffect) -> felt252 {
        StorePacking::pack(value.affect)
            + match value.target {
                Player::Player1 => PLAYER_1_PACKING_BITS,
                Player::Player2 => PLAYER_2_PACKING_BITS,
            }
    }
    fn unpack(value: felt252) -> RoundEffect {
        let u256 { low, high } = value.into();
        let variant: u16 = MaskDowncast::cast(high);
        let target = match ShiftCast::const_unpack::<SHIFT_2B>(high) {
            0_u16 => Player::Player1,
            1_u16 => Player::Player2,
            _ => panic!("Invalid value for Target"),
        };

        RoundEffect { target, affect: unpack_affect(variant, low) }
    }
}

#[derive(PanicDestruct)]
struct RoundEffects {
    base_hash: felt252,
    round: u32,
    this_round_hash: StorageBaseAddress,
    effect_counts: felt252,
    round_hashes: Felt252Dict<Nullable<StorageBaseAddress>>,
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
                effect_counts: effects.try_into().unwrap(),
            },
            next.try_into().unwrap(),
        )
    }

    fn get_affect(self: @RoundEffects, index: u8) -> RoundEffect {
        StorePacking::unpack(read_at_base_offset(*self.this_round_hash, index))
    }

    fn add_effect(ref self: RoundEffects, effect: RoundEffect, mut round: u32) {
        // let mut round_hash: StorageBaseAddress = self.round_hashes.get(round.into());
        round -= 1;
        if round > 31 {
            round = 31;
        }
        let round_u8: u8 = round.try_into().unwrap();
        let round_felt252: felt252 = round.into();
        let round_hash = match match_nullable(self.round_hashes.get(round_felt252)) {
            FromNullableResult::Null => {
                let hash = poseidon_hash_two(self.base_hash, round).into();
                self.round_hashes.insert(round_felt252, NullableTrait::new(hash));
                hash
            },
            FromNullableResult::NotNull(value) => value.unbox(),
        };

        let effect_count: u8 = BShiftCast::unpack(self.effect_counts, round_u8);
        self.effect_counts += GetShift::get_shift(round_u8);

        write_at_base_offset(round_hash, effect_count, StorePacking::pack(effect))
    }
}
