use ba_loadout::Attributes;
use ba_utils::storage::{FeltArrayReadWrite, ShortArrayStore};
use starknet::storage::{Mutable, StoragePath};
use crate::CombatantState;

pub type OpponentPath = StoragePath<Mutable<Opponent>>;

#[derive(Drop, starknet::Store)]
pub struct Opponent {
    pub attributes: Attributes,
    pub actions: Array<felt252>,
}


impl OpponentIntoState of Into<Opponent, CombatantState> {
    fn into(self: Opponent) -> CombatantState {
        self.attributes.into()
    }
}
