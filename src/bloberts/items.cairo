use dojo::{world::WorldStorage, model::{ModelStorage, ModelValueStorage}};
use super::external::{Seed, TokenTrait};
use blob_arena::{
    core::TTupleSize5, hash::HashStateTrait, items::{ItemTrait, ItemsTrait}, stats::UStats
};
use core::hash::into_felt252_based;
type SeedIds = TTupleSize5<felt252>;

const SEED_TRAIT_TYPE: felt252 = 'seed';
const CUSTOM_TRAIT_TYPE: felt252 = 'custom';


struct BlobertTraitsSeed {
    background: felt252,
    armour: felt252,
    jewelry: felt252,
    mask: felt252,
    weapon: felt252,
}

#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
enum BlobertTrait {
    Background,
    Armour,
    Jewelry,
    Mask,
    Weapon,
}

#[derive(Drop, Serde, Copy, PartialEq, Introspect)]
struct BlobertTraitKey {
    blobert_trait: BlobertTrait,
    blobert_trait_id: u8,
}

#[derive(Drop, Serde, Copy, PartialEq, Introspect)]
enum  BlobertItemKey{
    Normal: BlobertTraitKey,
    Custom: u8,
    AMMMA: u128,

} 

mod models {
    #[dojo:model]
    #[derive(Copy, Drop, Serde, PartialEq, IntrospectPacked)]
    struct BlobertItem {
        #[key]
        key:BlobertItemKey,
        stats: UStats,
    }

    #[dojo:model]
    #[derive(Copy, Drop, Serde, PartialEq, Introspect)]
    struct HasAttack {
        #[key]
        key:BlobertItemKey,
        #[key]
        attack_id: felt252,
        has: bool,
    }

    #[dojo:event]
    #[derive(Copy, Drop, Serde, PartialEq, Introspect)]
    struct BlobertItemName {
        #[key]
        key:BlobertItemKey,
        name: ByteArray,
    }
}

#[generate_trait]
impl BlobertItemImpl of BlobertItemTrait {
    fn get_blobert_item_stats(self: @WorldStorage, key: BlobertItemKey) -> IStats {
        ModelValueStorage::<WorldStorage, BlobertItem>::read_value(self, key).stats
    }

    fn set_blobet_item(ref self: WorldStorage, key: BlobertItemKey, name: ByteArray, stats: UStats, attacks: Span<AttackInput>) {
        self.write_model(@BlobertItem { key, stats, });
        self.emit_event(@BlobertItemName { key, name, });
    }
}


impl U8IntoBlobertSeedImpl of Into<u8, Seed> {
    fn into(self: u8) -> Seed {
        Seed { background: self, armour: self, jewelry: self, mask: self, weapon: self, }
    }
}


impl HashBlobertTrait<S, +HashStateTrait<S>, +Drop<S>> =
    into_felt252_based::HashImpl<BlobertTrait, S>;

impl BlobertTraitIntoFelt252 of Into<BlobertTrait, felt252> {
    fn into(self: BlobertTrait) -> felt252 {
        match self {
            BlobertTrait::Background => 'background',
            BlobertTrait::Armour => 'armour',
            BlobertTrait::Jewelry => 'jewelry',
            BlobertTrait::Mask => 'mask',
            BlobertTrait::Weapon => 'weapon',
        }
    }
}

impl U8IntoBlobertTrait of Into<u8, BlobertTrait> {
    fn into(self: u8) -> BlobertTrait {
        match self {
            0 => BlobertTrait::Background,
            1 => BlobertTrait::Armour,
            2 => BlobertTrait::Jewelry,
            3 => BlobertTrait::Mask,
            4 => BlobertTrait::Weapon,
            _ => panic!("Invalid BlobertTrait"),
        }
    }
}

#[generate_trait]
impl BlobertItems of BlobertItemsTrait {
    fn set_item_id(
        ref self: WorldStorage,
        trait_type: felt252,
        blobert_trait: BlobertTrait,
        blobert_trait_id: u8,
        item_id: felt252
    ) {
        self.write_model(@ItemMap { trait_type, blobert_trait, blobert_trait_id, item_id, });
    }
    fn get_item_id(
        self: @WorldStorage, trait_type: felt252, blobert_trait: BlobertTrait, blobert_trait_id: u8
    ) -> felt252 {
        ModelValueStorage::<
            WorldStorage, ItemMapValue
        >::read_value(self, (trait_type, blobert_trait, blobert_trait_id))
            .item_id
    }
    fn get_seed_item_ids(self: @WorldStorage, trait_type: felt252, traits: Seed) -> SeedIds {
        (
            self.get_item_id(trait_type, BlobertTrait::Background, traits.background),
            self.get_item_id(trait_type, BlobertTrait::Armour, traits.armour),
            self.get_item_id(trait_type, BlobertTrait::Jewelry, traits.jewelry),
            self.get_item_id(trait_type, BlobertTrait::Mask, traits.mask),
            self.get_item_id(trait_type, BlobertTrait::Weapon, traits.weapon),
        )
    }
    fn get_item_ids(self: @WorldStorage, blobert_trait: TokenTrait) -> SeedIds {
        match blobert_trait {
            TokenTrait::Regular(seed) => self.get_seed_item_ids(SEED_TRAIT_TYPE, seed),
            TokenTrait::Custom(custom_id) => self
                .get_seed_item_ids(CUSTOM_TRAIT_TYPE, custom_id.into()),
        }
    }
}

#[generate_trait]
impl BlobertStatsImpl of BlobertStatsTrait {
    fn get_blobert_item_ids(self: @WorldStorage, blobert_trait: TokenTrait) -> Array<felt252> {
        let (background, armour, jewelry, mask, weapon) = self.get_item_ids(blobert_trait);
        array![background, armour, jewelry, mask, weapon]
    }
    fn get_blobert_stats(self: @WorldStorage, blobert_trait: TokenTrait) -> UStats {
        self.get_items(self.get_blobert_item_ids(blobert_trait).span()).get_stats()
    }

    fn blobert_has_attack(
        self: @WorldStorage, blobert_trait: TokenTrait, item_id: felt252, attack_id: felt252
    ) -> bool {
        let mut item_ids = self.get_blobert_item_ids(blobert_trait);
        let mut has = false;
        loop {
            match item_ids.pop_front() {
                Option::Some(id) => { if id == item_id {
                    has = true;
                    break;
                } },
                Option::None => { break; },
            }
        };
        if has {
            self.check_has_attack(item_id, attack_id)
        } else {
            false
        }
    }
}
