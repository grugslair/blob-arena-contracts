use core::integer::u128_safe_divmod;

use starknet::{
    ContractAddress, get_caller_address, get_contract_address, get_block_timestamp, get_tx_info
};
use dojo::{world::WorldStorage, model::{ModelStorage, ModelValueStorage}};

use blob_arena::{
    uuid, utils::SeedProbability, hash::hash_value,
    collections::blobert::external::{Seed, TokenTrait}, world::WorldTrait, core::SaturatingInto
};
use super::blobert::{ArcadeBlobertTrait, ArcadeBlobert};

const ARMOUR_COUNT: u8 = 17;
const JEWELRY_COUNT: u8 = 8;
const BACKGROUND_COUNT: u8 = 12;
const MASK_COUNT: u8 = 26;
const WEAPON_COUNT: u8 = 43;

const SECONDS_IN_DAY: u64 = 86400;

#[dojo::model]
#[derive(Drop, Serde, Copy)]
struct LastMint {
    #[key]
    player: ContractAddress,
    timestamp: u64,
}

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

    let background: u8 = randomness.get_value(background_count).try_into().unwrap();
    let armour: u8 = randomness.get_value(armour_count).try_into().unwrap();

    // only allow the mask to be one of the first 8 masks
    // where the armour is sheep wool or kigurumi
    if armour == 0 || armour == 1 {
        mask_count = 8;
    };

    let jewelry: u8 = randomness.get_value(jewelry_count).try_into().unwrap();
    let mask: u8 = randomness.get_value(weapon_count).try_into().unwrap();
    let weapon: u8 = randomness.get_value(mask_count).try_into().unwrap();
    return Seed { background, armour, jewelry, mask, weapon };
}

#[generate_trait]
impl ArcadeBlobertMintImpl of ArcadeBlobertMintTrait {
    fn mint_blobert(ref self: WorldStorage) -> u256 {
        let caller = get_caller_address();
        let timestamp = get_block_timestamp();
        // TESTING: add this line back in
        // assert(timestamp > self.get_last_mint(caller) + SECONDS_IN_DAY, 'Only one mint in 24h');
        let token_id = hash_value(('arcade', get_tx_info().transaction_hash));
        let seed = generate_seed(token_id);

        self.set_arcade_blobert(token_id, caller, TokenTrait::Regular(seed));
        self.set_last_mint(caller, timestamp);
        token_id.into()
    }
    fn mint_blobert_with_traits(
        ref self: WorldStorage, player: ContractAddress, traits: TokenTrait
    ) -> u256 {
        self.assert_caller_is_creator();
        let token_id = uuid();

        self.set_arcade_blobert(token_id, player, traits);
        token_id.into()
    }
    fn get_last_mint(self: @WorldStorage, caller: ContractAddress) -> u64 {
        ModelValueStorage::<WorldStorage, LastMintValue>::read_value(self, caller).timestamp
    }
    fn set_last_mint(ref self: WorldStorage, player: ContractAddress, timestamp: u64) {
        self.write_model(@LastMint { player, timestamp });
    }
}
