use sai_core_utils::poseidon_serde::PoseidonSerde;
use sai_packing::SHIFT_4B;
use starknet::ContractAddress;

const NONE_INDEX: felt252 = 0_felt252;
const BACKGROUND_INDEX: felt252 = SHIFT_4B.into();
const ARMOUR_INDEX: felt252 = (SHIFT_4B * 2).into();
const JEWELRY_INDEX: felt252 = (SHIFT_4B * 3).into();
const MASK_INDEX: felt252 = (SHIFT_4B * 4).into();
const WEAPON_INDEX: felt252 = (SHIFT_4B * 5).into();
const CUSTOM_INDEX: felt252 = (SHIFT_4B * 6).into();

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
    fn indexes(self: @Seed) -> Span<felt252> {
        self.keys().span().into_iter().map(|k| k.index()).collect::<Array>().span()
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

#[generate_trait]
pub impl BlobertAttributeImpl of BlobertAttributeTrait {
    fn index(self: BlobertAttribute, index: u32) -> felt252 {
        match self {
            BlobertAttribute::None => NONE_INDEX,
            BlobertAttribute::Background => BACKGROUND_INDEX + index.into(),
            BlobertAttribute::Armour => ARMOUR_INDEX + index.into(),
            BlobertAttribute::Jewelry => JEWELRY_INDEX + index.into(),
            BlobertAttribute::Mask => MASK_INDEX + index.into(),
            BlobertAttribute::Weapon => WEAPON_INDEX + index.into(),
            BlobertAttribute::Custom => CUSTOM_INDEX + index.into(),
        }
    }
}

pub fn get_custom_index(index: u32) -> felt252 {
    CUSTOM_INDEX + index.into()
}

#[generate_trait]
pub impl BlobertAttributeKeyImpl of BlobertAttributeKeyTrait {
    fn index(self: BlobertAttributeKey) -> felt252 {
        match self {
            BlobertAttributeKey::None => NONE_INDEX,
            BlobertAttributeKey::Background(index) => BACKGROUND_INDEX + index.into(),
            BlobertAttributeKey::Armour(index) => ARMOUR_INDEX + index.into(),
            BlobertAttributeKey::Jewelry(index) => JEWELRY_INDEX + index.into(),
            BlobertAttributeKey::Mask(index) => MASK_INDEX + index.into(),
            BlobertAttributeKey::Weapon(index) => WEAPON_INDEX + index.into(),
            BlobertAttributeKey::Custom(index) => CUSTOM_INDEX + index.into(),
        }
    }
}

impl BlobertAttributeIntoFelt252 of Into<BlobertAttribute, felt252> {
    fn into(self: BlobertAttribute) -> felt252 {
        match self {
            BlobertAttribute::None => 0,
            BlobertAttribute::Background => 1,
            BlobertAttribute::Armour => 2,
            BlobertAttribute::Jewelry => 3,
            BlobertAttribute::Mask => 4,
            BlobertAttribute::Weapon => 5,
            BlobertAttribute::Custom => 6,
        }
    }
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
            BlobertAttributeKey::None => (BlobertAttribute::None, 0),
            BlobertAttributeKey::Background(index) => (BlobertAttribute::Background, index),
            BlobertAttributeKey::Armour(index) => (BlobertAttribute::Armour, index),
            BlobertAttributeKey::Jewelry(index) => (BlobertAttribute::Jewelry, index),
            BlobertAttributeKey::Mask(index) => (BlobertAttribute::Mask, index),
            BlobertAttributeKey::Weapon(index) => (BlobertAttribute::Weapon, index),
            BlobertAttributeKey::Custom(index) => (BlobertAttribute::Custom, index),
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
