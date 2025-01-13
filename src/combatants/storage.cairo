use starknet::ContractAddress;
use dojo::{world::WorldStorage, model::{ModelStorage, Model, ModelValueStorage}};
use blob_arena::{
    combatants::{
        CombatantInfo, CombatantState, CombatantInfoTrait, CombatantStateTrait, CombatantToken,
        components::{get_combatant_id, make_combatant_state, CombatantTokenValue}
    },
    stats::UStats,
};

#[generate_trait]
impl CombatantRWImpl of CombatantStorage {
    fn get_combatant_info(self: @WorldStorage, id: felt252) -> CombatantInfo {
        self.read_model(id)
    }

    fn get_combatant_infos(self: @WorldStorage, ids: Span<felt252>) -> Array<CombatantInfo> {
        self.read_models(ids)
    }

    fn set_combatant_info(
        ref self: WorldStorage, id: felt252, combat_id: felt252, player: ContractAddress
    ) {
        self.write_model(@CombatantInfo { id, combat_id, player });
    }

    fn create_combatant_state(ref self: WorldStorage, id: felt252, stats: UStats) {
        self.write_model(@make_combatant_state(id, @stats));
    }

    fn get_combatant_state(self: @WorldStorage, id: felt252) -> CombatantState {
        self.read_model(id)
    }

    fn get_combatant_states(self: @WorldStorage, ids: Span<felt252>) -> Array<CombatantState> {
        self.read_models(ids)
    }

    fn set_combatant_states(ref self: WorldStorage, states: Span<@CombatantState>) {
        self.write_models(states)
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

    fn get_combatant_token_value(self: @WorldStorage, id: felt252) -> CombatantTokenValue {
        self.read_value(id)
    }

    fn get_combatant_token_address(self: @WorldStorage, id: felt252) -> ContractAddress {
        self
            .read_member(
                Model::<CombatantToken>::ptr_from_keys(id), selector!("collection_address")
            )
    }

    fn set_combatant_token(
        ref self: WorldStorage, id: felt252, collection_address: ContractAddress, token_id: u256
    ) {
        self.write_model(@CombatantToken { id, collection_address, token_id });
    }
}
