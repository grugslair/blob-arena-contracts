use starknet::ContractAddress;

use dojo::world::{WorldStorage, IWorldDispatcher};

use crate::stats::UStats;
use crate::world::WorldTrait;
use super::{AmmaBlobertStorage, AMMA_BLOBERT_NAMESPACE_HASH};
use super::super::{TokenAttributes, BlobertItemKey};
use super::super::items::{BlobertItemsTrait, BlobertItemStorage};


fn custom_attack_slot(item_id: felt252, slot: felt252) -> (BlobertItemKey, felt252) {
    (BlobertItemKey::Custom(item_id), slot)
}


#[generate_trait]
impl AmmaBlobertImpl of AmmaBlobertTrait {
    fn get_amma_token_stats(self: @WorldStorage, token_id: u256) -> UStats {
        self.get_amma_fighter_stats(self.get_amma_token_fighter(token_id).into())
    }
    fn get_amma_token_attack_slot(
        self: @WorldStorage, token_id: u256, item_id: felt252, slot: felt252,
    ) -> felt252 {
        self
            .get_amma_fighter_attack_slot(
                self.get_amma_token_fighter(token_id).into(), item_id, slot,
            )
    }
    fn get_amma_token_attack_slots(
        self: @WorldStorage, token_id: u256, item_slots: Array<(felt252, felt252)>,
    ) -> Array<felt252> {
        let fighter = self.get_amma_token_fighter(token_id);
        self.get_amma_fighter_attack_slots(fighter.into(), item_slots)
    }

    fn get_amma_fighter_attack_slot(
        self: @WorldStorage, fighter: u32, item_id: felt252, slot: felt252,
    ) -> felt252 {
        match item_id {
            0 => self.get_blobert_attack_slot(BlobertItemKey::Custom(fighter.into()), slot),
            _ => 0,
        }
    }

    fn get_amma_fighter_attack_slots(
        self: @WorldStorage, fighter: u32, item_slots: Array<(felt252, felt252)>,
    ) -> Array<felt252> {
        let mut slots: Array<(BlobertItemKey, felt252)> = Default::default();
        for (item_id, slot) in item_slots {
            match item_id {
                0 => slots.append(custom_attack_slot(fighter.into(), slot)),
                _ => {},
            };
        };
        self.get_blobert_attack_slots(slots.span())
    }
    fn fill_amma_fighter_attack_slots(
        ref self: WorldStorage, fighter: u32, attacks: Array<felt252>,
    ) {
        self.fill_blobert_item_attack_slots(BlobertItemKey::Custom(fighter.into()), attacks);
    }
}
