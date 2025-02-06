use starknet::{ContractAddress};
use dojo::world::{WorldStorage};
use blob_arena::{stats::UStats, id_trait::{IdTrait, TIdsImpl}, uuid};


#[dojo::model]
#[derive(Drop, Serde)]
struct Item {
    #[key]
    id: felt252,
    stats: UStats,
}

#[dojo::event]
#[derive(Drop, Serde)]
struct ItemName {
    #[key]
    id: felt252,
    name: ByteArray,
}

#[dojo::model]
#[derive(Drop, Serde)]
struct HasAttack {
    #[key]
    item_id: felt252,
    #[key]
    attack_id: felt252,
    has: bool,
}

impl ItemIdImpl of IdTrait<Item> {
    fn id(self: @Item) -> felt252 {
        *self.id
    }
}

impl ItemIdsImpl = TIdsImpl<Item>;
