#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
enum TokenAttributes {
    // regular tokens are identified by seed
    Seed: Seed,
    // custom tokens are indentified by index
    Custom: felt252,
}


#[derive(Copy, Drop, Serde, Hash, PartialEq, Introspect, starknet::Store)]
struct Seed {
    background: u32,
    armour: u32,
    jewelry: u32,
    mask: u32,
    weapon: u32,
}

#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
enum BlobertAttribute {
    Background,
    Armour,
    Jewelry,
    Mask,
    Weapon,
}

