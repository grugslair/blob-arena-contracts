use alexandria_data_structures::array_ext::ArrayTraitExt;
use starknet::{ContractAddress};
use dojo::world::{WorldStorage};
use blob_arena::{stats::UStats, id_trait::{IdTrait, TIdsImpl}, uuid};

#[derive(Drop, Serde, Copy)]
struct Item {
    id: felt252,
    stats: UStats,
}

mod models {
    use blob_arena::stats::UStats;

    #[dojo::model]
    #[derive(Drop, Serde)]
    struct Item {
        #[key]
        id: felt252,
        name: ByteArray,
        stats: UStats,
    }

    #[dojo::model]
    #[derive(Drop, Serde, Copy)]
    struct HasAttack {
        #[key]
        item_id: felt252,
        #[key]
        attack_id: felt252,
        has: bool,
    }
}

use models::{Item as ItemModel, ItemValue, HasAttack, HasAttackValue};

impl ItemIdImpl of IdTrait<Item> {
    fn id(self: @Item) -> felt252 {
        *self.id
    }
}

impl ItemIdsImpl = TIdsImpl<Item>;

#[generate_trait]
impl ItemsImpl of ItemsTrait {
    fn get_stats(mut self: Span<Item>) -> UStats {
        let mut stats: UStats = Default::default();
        loop {
            match self.pop_front() {
                Option::Some(item) => { stats = stats + *item.stats; },
                Option::None => { break stats; },
            }
        }
    }
}

impl ItemModelIntoItem of Into<models::Item, Item> {
    fn into(self: models::Item) -> Item {
        Item { id: self.id, stats: self.stats, }
    }
}
