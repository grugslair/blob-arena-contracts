use core::num::traits::Zero;

use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
use dojo::world::WorldStorage;

use crate::utils::SeedProbability;
use crate::constants::SECONDS_24_HOURS;
use crate::permissions::{Permissions, Role};

use super::FreeBlobertStorage;
use super::super::{TokenAttributes, Seed};
use super::super::world_blobert::WorldBlobertStorage;

const ARMOUR_COUNT: u8 = 17;
const JEWELRY_COUNT: u8 = 8;
const BACKGROUND_COUNT: u8 = 12;
const MASK_COUNT: u8 = 26;
const WEAPON_COUNT: u8 = 43;

const MAX_TOKENS_OWNED: u64 = 10;


fn u8_to_u128_nz(value: u8) -> NonZero<u128> {
    TryInto::<u8, u128>::try_into(value).unwrap().try_into().unwrap()
}

fn generate_seed(randomness: felt252) -> Seed {
    let mut randomness = Into::<felt252, u256>::into(randomness).low;

    let background_count: NonZero<u128> = u8_to_u128_nz(BACKGROUND_COUNT);
    let armour_count: NonZero<u128> = u8_to_u128_nz(ARMOUR_COUNT);
    let jewelry_count: NonZero<u128> = u8_to_u128_nz(JEWELRY_COUNT);
    let weapon_count: NonZero<u128> = u8_to_u128_nz(WEAPON_COUNT);
    let mut mask_count: NonZero<u128> = u8_to_u128_nz(MASK_COUNT);

    let background: u32 = randomness.get_value(background_count).try_into().unwrap();
    let armour: u32 = randomness.get_value(armour_count).try_into().unwrap();

    // only allow the mask to be one of the first 8 masks
    // where the armour is sheep wool or kigurumi
    if armour == 0 || armour == 1 {
        mask_count = 8;
    };

    let jewelry: u32 = randomness.get_value(jewelry_count).try_into().unwrap();
    let mask: u32 = randomness.get_value(mask_count).try_into().unwrap();
    let weapon: u32 = randomness.get_value(weapon_count).try_into().unwrap();
    return Seed { background, armour, jewelry, mask, weapon };
}

#[generate_trait]
impl FreeBlobertImpl of FreeBlobertTrait {
    fn mint_random_blobert(
        ref self: WorldStorage, owner: ContractAddress, randomness: felt252,
    ) -> u256 {
        let current_tokens_owned = self.get_amount_tokens_owned(owner);
        let timestamp = get_block_timestamp();
        if !self.has_permission(owner, Role::Tester) {
            assert(
                timestamp >= self.get_last_mint(owner) + SECONDS_24_HOURS,
                'Can only mint every 24 hours',
            );
            let current_tokens_owned = self.get_amount_tokens_owned(owner);
            assert(current_tokens_owned < MAX_TOKENS_OWNED, 'Max tokens owned');
        };
        self.set_amount_tokens_owned(owner, current_tokens_owned + 1);
        self.set_last_mint(owner, timestamp);
        self
            .set_blobert_token(
                randomness.into(), owner, TokenAttributes::Seed(generate_seed(randomness)),
            );
        randomness.into()
    }
    fn burn_blobert(ref self: WorldStorage, token_id: u256) {
        let caller = get_caller_address();
        assert(self.get_blobert_token_owner(token_id) == caller, 'Not owner');
        self.set_amount_tokens_owned(caller, self.get_amount_tokens_owned(caller) - 1);
        self.set_blobert_token_owner(token_id, Zero::zero());
    }
}
