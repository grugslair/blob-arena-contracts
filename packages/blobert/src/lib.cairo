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

#[derive(Copy, Drop, Serde, PartialEq, Introspect, Default)]
pub enum BlobertAttribute {
    #[default]
    Background,
    Armour,
    Jewelry,
    Mask,
    Weapon,
}
