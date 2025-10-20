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

/// Represents the different types of trait configurations for Blobert NFTs
///
/// # Variants
/// * `Seed` - Procedurally generated traits using a seed-based system with 5 trait categories
/// * `Custom` - Manually configured traits referenced by a custom index identifier
#[derive(Copy, Drop, Serde, PartialEq, Introspect, Default)]
pub enum TokenTraits {
    #[default]
    Seed: Seed,
    Custom: u32,
}

/// Seed-based trait configuration for Blobert Traits
///
/// Contains indices for each visual trait category that define the Blobert's appearance.
/// Each field represents a specific trait slot with its corresponding index value.
///
/// # Fields
/// * `background` - Background
/// * `armour` - Armor/clothing
/// * `jewelry` - Jewelry/accessories
/// * `mask` - Face mask/headgear
/// * `weapon` - Weapon/tool
#[derive(Copy, Drop, Serde, PartialEq, Introspect, starknet::Store, Default)]
pub struct Seed {
    pub background: u32,
    pub armour: u32,
    pub jewelry: u32,
    pub mask: u32,
    pub weapon: u32,
}

/// Enumeration of all available Blobert trait categories
///
/// Defines the different types of visual traits that can be applied to a Blobert.
/// Used for trait identification and categorization in the trait system.
///
/// # Variants
/// * `None` - No trait or default state
/// * `Background` - Background
/// * `Armour` - Armor and clothing
/// * `Jewelry` - Jewelry and accessories
/// * `Mask` - Face masks and headgear
/// * `Weapon` - Weapons and tools
/// * `Custom` - Custom or special trait configurations
#[derive(Copy, Drop, Serde, PartialEq, Introspect, Default)]
pub enum BlobertTrait {
    #[default]
    None,
    Background,
    Armour,
    Jewelry,
    Mask,
    Weapon,
    Custom,
}

/// Trait category with associated index value for specific trait identification
///
/// Combines a trait category with its specific index value, allowing for
/// precise identification of individual traits within each category.
///
/// # Variants
/// * `None` - No specific trait
/// * `Background(u32)` - Background trait with specific index
/// * `Armour(u32)` - Armor trait with specific index
/// * `Jewelry(u32)` - Jewelry trait with specific index
/// * `Mask(u32)` - Mask trait with specific index
/// * `Weapon(u32)` - Weapon trait with specific index
/// * `Custom(u32)` - Custom trait with specific index
#[derive(Copy, Drop, Serde, PartialEq, Introspect, Default)]
pub enum BlobertTraitKey {
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
pub impl SeedImpl of SeedTrait {
    fn keys(self: @Seed) -> [BlobertTraitKey; 5] {
        [
            BlobertTraitKey::Background(*self.background), BlobertTraitKey::Armour(*self.armour),
            BlobertTraitKey::Jewelry(*self.jewelry), BlobertTraitKey::Mask(*self.mask),
            BlobertTraitKey::Weapon(*self.weapon),
        ]
    }
    fn indexes(self: @Seed) -> Span<felt252> {
        self.keys().span().into_iter().map(|k| k.index()).collect::<Array>().span()
    }
}


#[generate_trait]
pub impl BlobertTraitImpl of BlobertTraitTrait {
    fn index(self: BlobertTrait, index: u32) -> felt252 {
        match self {
            BlobertTrait::None => NONE_INDEX,
            BlobertTrait::Background => BACKGROUND_INDEX + index.into(),
            BlobertTrait::Armour => ARMOUR_INDEX + index.into(),
            BlobertTrait::Jewelry => JEWELRY_INDEX + index.into(),
            BlobertTrait::Mask => MASK_INDEX + index.into(),
            BlobertTrait::Weapon => WEAPON_INDEX + index.into(),
            BlobertTrait::Custom => CUSTOM_INDEX + index.into(),
        }
    }
}

pub fn get_custom_index(index: u32) -> felt252 {
    CUSTOM_INDEX + index.into()
}

#[generate_trait]
pub impl BlobertTraitKeyImpl of BlobertTraitKeyTrait {
    fn index(self: BlobertTraitKey) -> felt252 {
        match self {
            BlobertTraitKey::None => NONE_INDEX,
            BlobertTraitKey::Background(index) => BACKGROUND_INDEX + index.into(),
            BlobertTraitKey::Armour(index) => ARMOUR_INDEX + index.into(),
            BlobertTraitKey::Jewelry(index) => JEWELRY_INDEX + index.into(),
            BlobertTraitKey::Mask(index) => MASK_INDEX + index.into(),
            BlobertTraitKey::Weapon(index) => WEAPON_INDEX + index.into(),
            BlobertTraitKey::Custom(index) => CUSTOM_INDEX + index.into(),
        }
    }
}

impl BlobertTraitIntoFelt252 of Into<BlobertTrait, felt252> {
    fn into(self: BlobertTrait) -> felt252 {
        match self {
            BlobertTrait::None => 0,
            BlobertTrait::Background => 1,
            BlobertTrait::Armour => 2,
            BlobertTrait::Jewelry => 3,
            BlobertTrait::Mask => 4,
            BlobertTrait::Weapon => 5,
            BlobertTrait::Custom => 6,
        }
    }
}


// impl BlobertTraitIntoBlobertTrait of Into<BlobertTrait, BlobertTrait> {
//     fn into(self: BlobertTrait) -> BlobertTrait {
//         match self {
//             BlobertTrait::Background => BlobertTrait::Background,
//             BlobertTrait::Armour => BlobertTrait::Armour,
//             BlobertTrait::Jewelry => BlobertTrait::Jewelry,
//             BlobertTrait::Mask => BlobertTrait::Mask,
//             BlobertTrait::Weapon => BlobertTrait::Weapon,
//         }
//     }
// }

impl BlobertTraitKeyIntoBlobertTrait of Into<BlobertTraitKey, (BlobertTrait, u32)> {
    fn into(self: BlobertTraitKey) -> (BlobertTrait, u32) {
        match self {
            BlobertTraitKey::None => (BlobertTrait::None, 0),
            BlobertTraitKey::Background(index) => (BlobertTrait::Background, index),
            BlobertTraitKey::Armour(index) => (BlobertTrait::Armour, index),
            BlobertTraitKey::Jewelry(index) => (BlobertTrait::Jewelry, index),
            BlobertTraitKey::Mask(index) => (BlobertTrait::Mask, index),
            BlobertTraitKey::Weapon(index) => (BlobertTrait::Weapon, index),
            BlobertTraitKey::Custom(index) => (BlobertTrait::Custom, index),
        }
    }
}

/// Interface for accessing Blobert NFT trait information
///
/// Provides external access to retrieve trait configurations for specific Blobert tokens.
/// Implementations should return the complete trait setup for the requested token.
#[starknet::interface]
trait IBlobert<TState> {
    /// Retrieves the trait configuration for a specific Blobert token
    ///
    /// # Arguments
    /// * `token_id` - The unique identifier of the Blobert token
    ///
    /// # Returns
    /// * `TokenTraits` - The complete trait configuration (either Seed-based or Custom)
    fn traits(self: @TState, token_id: u256) -> TokenTraits;
}

/// Utility function to retrieve Blobert traits from any collection contract
///
/// # Arguments
/// * `collection` - The contract address of the Blobert collection
/// * `token_id` - The unique identifier of the Blobert token
///
/// # Returns
/// * `TokenTraits` - The trait configuration for the specified token
pub fn get_blobert_traits(collection: ContractAddress, token_id: u256) -> TokenTraits {
    IBlobertDispatcher { contract_address: collection }.traits(token_id)
}
