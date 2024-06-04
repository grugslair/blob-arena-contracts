use core::array::ArrayTrait;
use starknet::{ContractAddress};
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};
use blob_arena::{
    models::ItemModel,
    components::{stats::Stats, attack::{Attack, AttackTrait}, utils::{IdTrait, IdsTrait, TIdsImpl}}
};

#[derive(Drop, Serde)]
struct Item {
    id: u128,
    name: ByteArray,
    stats: Stats,
    attacks: Array<Attack>,
}

impl ItemIdImpl of IdTrait<Item> {
    fn id(self: @Item) -> u128 {
        *self.id
    }
}

impl ItemIdsImpl = TIdsImpl<Item>;

#[generate_trait]
impl ItemsImpl of ItemsTrait {
    fn get_attacks(self: Span<Item>) -> Array<Attack> {
        let mut attacks: Array<Attack> = ArrayTrait::new();
        let (len, mut n) = (self.len(), 0_usize);
        while n < len {
            let span = self.at(n).attacks.span();
            attacks.append_span(span);
            n += 1;
        };
        attacks
    }
    fn get_stats(self: Span<Item>) -> Stats {
        let mut stats: Stats = 0_u8.into();
        let (len, mut n) = (self.len(), 0_usize);
        while n < len {
            stats = stats + *self.at(n).stats;
            n += 1;
        };
        stats
    }
    fn get_health(self: Array<Item>) -> u8 {
        100
    }
}

impl ItemIntoItemModel of Into<Item, ItemModel> {
    fn into(self: Item) -> ItemModel {
        let mut attack_ids: Array<u128> = ArrayTrait::new();
        let (len, mut n) = (attack_ids.len(), 0_usize);
        while (n < len) {
            attack_ids.append(*self.attacks.at(n).id);
            n += 1;
        };
        ItemModel { id: self.id, name: self.name, stats: self.stats, attacks: attack_ids }
    }
}

#[generate_trait]
impl ItemImpl of ItemTrait {
    fn get_item(self: IWorldDispatcher, id: u128) -> Item {
        let ItemModel { id, name, stats, attacks: attack_ids } = get!(self, id, ItemModel);
        let attacks = self.get_attacks(attack_ids);
        Item { id, name, stats, attacks }
    }
    fn get_items(self: IWorldDispatcher, ids: Array<u128>) -> Array<Item> {
        let mut items: Array<Item> = ArrayTrait::new();
        let (len, mut n) = (ids.len(), 0_usize);
        while n < len {
            items.append(self.get_item(*ids[n]));
            n += 1;
        };
        items
    }
}

