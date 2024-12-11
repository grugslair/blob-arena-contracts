use starknet::ContractAddress;
use dojo::{world::WorldStorage, model::{ModelStorage, Model}};
use blob_arena::{
    combatants::{
        CombatantInfo, CombatantState, CombatantInfoTrait, CombatantStateTrait, CombatantToken,
        components::{get_combatant_id, make_combatant_state}
    },
};

#[generate_trait]
impl CombatantRWImpl of CombatantStorage {
    fn get_combatant_info(self: @WorldStorage, id: felt252) -> CombatantInfo {
        self.read_model(id)
    }

    fn get_combatant_state(self: @WorldStorage, id: felt252) -> CombatantState {
        self.read_model(id)
    }

    fn get_combatant_states(self: @WorldStorage, ids: Span<felt252>) -> Array<CombatantState> {
        self.read_models(ids)
    }
    fn get_combatant_info_in_combat(self: @WorldStorage, id: felt252) -> CombatantInfo {
        let combatant = self.get_combatant_info(id);
        assert(combatant.combat_id.is_non_zero(), 'Not valid combatant');
        combatant
    }
    fn get_callers_combatant_info(self: @WorldStorage, id: felt252) -> CombatantInfo {
        let combatant = self.get_combatant_info(id);
        combatant.assert_caller();
        combatant
    }
    fn get_player(self: @WorldStorage, id: felt252) -> ContractAddress {
        self.read_member(Model::<CombatantInfo>::ptr_from_keys(id), selector!("player"))
    }
}
