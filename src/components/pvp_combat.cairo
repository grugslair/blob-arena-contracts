use starknet::{ContractAddress, get_caller_address, get_block_number};
use dojo::world::{WorldStorage, ModelStorage};
use blob_arena::{
    components::{
        attack::{Attack, AttackTrait}, combatant::{CombatantInfo, CombatantState, CombatantTrait},
        combat::{Phase,}, utils::{AB, ABT, ABTTrait, ABTImpl, ABTLogicTrait}
    },
    models::{PvPCombatantsModel, CombatState},
};


#[generate_trait]
impl PvPCombatImpl of PvPCombatTrait {
    fn set_pvp_combatants<T, +Into<T, (felt252, felt252)>>(
        ref self: WorldStorage, id: felt252, combatants: T
    ) {
        set!(self, PvPCombatantsModel { id, combatants: combatants.into() });
    }
    fn get_pvp_combatants_model(self: @WorldStorage, id: felt252) -> PvPCombatantsModel {
        get!((*self), id, PvPCombatantsModel)
    }
    fn get_pvp_combatants(self: @WorldStorage, id: felt252) -> ABT<felt252> {
        let combatants = ABTTrait::new_from_tuple(self.get_pvp_combatants_model(id).combatants);
        assert(combatants.is_neither_zero(), 'Combatants not set');
        combatants
    }
}
