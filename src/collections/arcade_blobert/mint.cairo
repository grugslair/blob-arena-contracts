use core::integer::u128_safe_divmod;

use starknet::{
    ContractAddress, get_caller_address, get_contract_address, get_block_timestamp, get_tx_info
};
use dojo::{world::WorldStorage, model::{ModelStorage, Model, ModelValueStorage}};

use blob_arena::{
    uuid, world::incrementor, utils::SeedProbability, hash::hash_value, collections::blobert::Seed,
    world::WorldTrait, core::SaturatingInto
};


use super::{ArcadeBlobertStorage, storage::TokenAttributes,};

const ARMOUR_COUNT: u8 = 17;
const JEWELRY_COUNT: u8 = 8;
const BACKGROUND_COUNT: u8 = 12;
const MASK_COUNT: u8 = 26;
const WEAPON_COUNT: u8 = 43;

const SECONDS_IN_DAY: u64 = 86400;


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
impl ArcadeBlobertMintImpl of ArcadeBlobertMintTrait {
    fn mint_random_blobert(ref self: WorldStorage, owner: ContractAddress) -> u256 {
        let token_id = hash_value(('arcade', incrementor('SEED-ITER')));

        self.set_blobert_token(token_id, owner, TokenAttributes::Seed(generate_seed(token_id)));
        token_id.into()
    }
    fn mint_blobert_with_seed(ref self: WorldStorage, player: ContractAddress, seed: Seed) -> u256 {
        let token_id = uuid();
        self.set_blobert_token(token_id, player, TokenAttributes::Seed(seed));
        token_id.into()
    }
    fn mint_custom_blobert(
        ref self: WorldStorage, player: ContractAddress, custom_id: felt252
    ) -> u256 {
        let token_id = uuid();
        self.set_blobert_token(token_id, player, TokenAttributes::Custom(custom_id));
        token_id.into()
    }
}
