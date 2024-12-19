use blob_arena::stats::UStats;


#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
struct SeedItem {
    attribute: BlobertAttribute,
    attribute_id: u32,
}

#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
enum BlobertItemKey {
    Seed: SeedItem,
    Custom: felt252,
}

#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
enum TokenAttributes {
    // regular tokens are identified by seed
    Seed: Seed,
    // custom tokens are indentified by index
    Custom: felt252,
}


#[derive(Copy, Drop, Serde, Hash, PartialEq, IntrospectPacked)]
struct Seed {
    background: u32,
    armour: u32,
    jewelry: u32,
    mask: u32,
    weapon: u32,
}

#[derive(Copy, Drop, Serde, PartialEq, IntrospectPacked)]
enum BlobertAttribute {
    Background,
    Armour,
    Jewelry,
    Mask,
    Weapon,
}

#[dojo::model]
#[derive(Drop, Serde, Copy)]
struct BlobertItem {
    #[key]
    key: BlobertItemKey,
    stats: UStats,
}


#[dojo::event]
#[derive(Drop, Serde)]
struct BlobertItemName {
    #[key]
    id: felt252,
    name: ByteArray,
}

#[dojo::model]
#[derive(Drop, Serde)]
struct AttackSlot {
    #[key]
    item_key: BlobertItemKey,
    #[key]
    slot: felt252,
    attack_id: felt252,
}


fn to_seed_key(attribute: BlobertAttribute, attribute_id: u32) -> BlobertItemKey {
    BlobertItemKey::Seed(SeedItem { attribute, attribute_id })
}


#[generate_trait]
impl SeedImpl of SeedTrait {
    fn get_attr(self: @Seed, attribute: BlobertAttribute) -> u32 {
        match attribute {
            BlobertAttribute::Background => *self.background,
            BlobertAttribute::Armour => *self.armour,
            BlobertAttribute::Jewelry => *self.jewelry,
            BlobertAttribute::Mask => *self.mask,
            BlobertAttribute::Weapon => *self.weapon,
        }
    }

    fn to_item_key(self: @Seed, attribute: BlobertAttribute) -> BlobertItemKey {
        to_seed_key(attribute, self.get_attr(attribute))
    }

    fn try_to_item_key(self: @Seed, item_id: felt252) -> Option<BlobertItemKey> {
        match item_id.try_into() {
            Option::Some(attribute) => Option::Some(self.to_item_key(attribute)),
            Option::None => Option::None,
        }
    }


    fn to_item_keys(self: @Seed) -> Span<BlobertItemKey> {
        [
            to_seed_key(BlobertAttribute::Background, *self.background),
            to_seed_key(BlobertAttribute::Armour, *self.armour),
            to_seed_key(BlobertAttribute::Jewelry, *self.jewelry),
            to_seed_key(BlobertAttribute::Mask, *self.mask),
            to_seed_key(BlobertAttribute::Weapon, *self.weapon),
        ].span()
    }
}

impl Felt252TryIntoBlobertTrait of TryInto<felt252, BlobertAttribute> {
    fn try_into(self: felt252) -> Option<BlobertAttribute> {
        match self {
            0 => Option::None,
            1 => Option::Some(BlobertAttribute::Armour),
            2 => Option::Some(BlobertAttribute::Background),
            3 => Option::Some(BlobertAttribute::Jewelry),
            4 => Option::Some(BlobertAttribute::Mask),
            5 => Option::Some(BlobertAttribute::Weapon),
            _ => Option::None,
        }
    }
}


#[generate_trait]
impl TokenAttributesImpl of TokenAttributesTrait {
    fn to_item_key(self: TokenAttributes, item_id: felt252) -> Option<BlobertItemKey> {
        match self {
            TokenAttributes::Seed(seed) => seed.try_to_item_key(item_id),
            TokenAttributes::Custom(index) => match item_id {
                0 => Option::Some(BlobertItemKey::Custom(index)),
                _ => Option::None,
            },
        }
    }
}

