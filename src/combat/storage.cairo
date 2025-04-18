use dojo::{world::WorldStorage, model::{ModelStorage, Model}, event::EventStorage};
use blob_arena::{combat::{CombatState, Phase}, attacks::results::{AttackResult, RoundResult}};

#[generate_trait]
impl CombatImpl of CombatStorage {
    fn new_combat_state(ref self: WorldStorage, id: felt252) {
        self.write_model(@CombatState { id, phase: Phase::Created, round: 1 });
    }
    fn get_combat_state(self: @WorldStorage, id: felt252) -> CombatState {
        self.read_model(id)
    }
    fn set_combat_state(ref self: WorldStorage, state: CombatState) {
        self.write_model(@state);
    }
    fn get_combat_phase(self: @WorldStorage, id: felt252) -> Phase {
        self.read_member(Model::<CombatState>::ptr_from_keys(id), selector!("phase"))
    }
    fn set_combat_phase(ref self: WorldStorage, id: felt252, phase: Phase) {
        self.write_member(Model::<CombatState>::ptr_from_keys(id), selector!("phase"), phase);
    }
    fn get_combat_winner(self: @WorldStorage, id: felt252) -> felt252 {
        match self.get_combat_phase(id) {
            Phase::Ended(winner) => winner,
            _ => panic!("Combat not ended")
        }
    }
    fn set_combat_winner(ref self: WorldStorage, id: felt252, winner: felt252) {
        self.set_combat_phase(id, Phase::Ended(winner));
    }

    fn emit_round_result(
        ref self: WorldStorage, combat_id: felt252, round: u32, attacks: Array<AttackResult>
    ) {
        self.emit_event(@RoundResult { combat_id, round, attacks: attacks });
    }
}
