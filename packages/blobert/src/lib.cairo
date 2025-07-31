use sai_core_utils::poseidon_serde::PoseidonSerde;
use starknet::ContractAddress;


#[derive(Copy, Drop, Serde, PartialEq, Introspect, Default)]
pub enum TokenAttributes {
    #[default]
    Seed: Seed,
    Custom: u32,
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
pub enum BlobertTrait {
    #[default]
    Background,
    Armour,
    Jewelry,
    Mask,
    Weapon,
}

#[derive(Copy, Drop, Serde, PartialEq, Introspect, Default)]
pub enum BlobertAttribute {
    #[default]
    None,
    Background,
    Armour,
    Jewelry,
    Mask,
    Weapon,
    Custom,
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
    Custom: u32,
}

impl BlobertTraitIntoBlobertAttribute of Into<BlobertTrait, BlobertAttribute> {
    fn into(self: BlobertTrait) -> BlobertAttribute {
        match self {
            BlobertTrait::Background => BlobertAttribute::Background,
            BlobertTrait::Armour => BlobertAttribute::Armour,
            BlobertTrait::Jewelry => BlobertAttribute::Jewelry,
            BlobertTrait::Mask => BlobertAttribute::Mask,
            BlobertTrait::Weapon => BlobertAttribute::Weapon,
        }
    }
}

impl BlobertAttributeKeyIntoBlobertAttribute of Into<BlobertAttributeKey, (BlobertAttribute, u32)> {
    fn into(self: BlobertAttributeKey) -> (BlobertAttribute, u32) {
        match self {
            BlobertAttributeKey::Background(index) => (BlobertAttribute::Background, index),
            BlobertAttributeKey::Armour(index) => (BlobertAttribute::Armour, index),
            BlobertAttributeKey::Jewelry(index) => (BlobertAttribute::Jewelry, index),
            BlobertAttributeKey::Mask(index) => (BlobertAttribute::Mask, index),
            BlobertAttributeKey::Weapon(index) => (BlobertAttribute::Weapon, index),
            BlobertAttributeKey::Custom(index) => (BlobertAttribute::Custom, index),
            BlobertAttributeKey::None => (BlobertAttribute::None, 0),
        }
    }
}

#[starknet::interface]
trait IBlobert<TState> {
    fn traits(self: @TState, token_id: u256) -> TokenAttributes;
}

pub fn get_blobert_attributes(collection: ContractAddress, token_id: u256) -> TokenAttributes {
    IBlobertDispatcher { contract_address: collection }.traits(token_id)
}
