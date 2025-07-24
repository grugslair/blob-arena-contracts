use arena_blobert::{IArenaBlobertDispatcher, IArenaBlobertDispatcherTrait};
use sai_core_utils::poseidon_serde::PoseidonSerde;
use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, PartialEq, Introspect, Default)]
pub enum TokenAttributes {
    #[default]
    Seed: Seed,
    Custom: felt252,
}


#[derive(Copy, Drop, Serde, PartialEq, Introspect, starknet::Store, Default)]
pub struct Seed {
    pub background: u32,
    pub armour: u32,
    pub jewelry: u32,
    pub mask: u32,
    pub weapon: u32,
}


#[generate_trait]
pub impl SeedImpl of SeedTrait {
    fn keys(self: @Seed) -> [BlobertAttributeKey; 5] {
        [
            BlobertAttributeKey::Background(*self.background),
            BlobertAttributeKey::Armour(*self.armour), BlobertAttributeKey::Jewelry(*self.jewelry),
            BlobertAttributeKey::Mask(*self.mask), BlobertAttributeKey::Weapon(*self.weapon),
        ]
    }
    fn key_hashes(self: @Seed) -> Array<felt252> {
        self.keys().span().into_iter().map(|k| k.poseidon_hash()).collect()
    }
}


#[derive(Copy, Drop, Serde, PartialEq, Introspect, Default)]
pub enum BlobertAttribute {
    #[default]
    Background,
    Armour,
    Jewelry,
    Mask,
    Weapon,
}

#[derive(Copy, Drop, Serde, PartialEq, Introspect, Default)]
pub enum BlobertAttributeKey {
    #[default]
    None,
    Background: u32,
    Armour: u32,
    Jewelry: u32,
    Mask: u32,
    Weapon: u32,
    Custom: felt252,
}


pub fn get_blobert_attributes(collection: ContractAddress, token_id: u256) -> TokenAttributes {
    IArenaBlobertDispatcher { contract_address: collection }.traits(token_id)
}
