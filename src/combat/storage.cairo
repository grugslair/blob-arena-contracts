use starknet::ContractAddress;
use dojo::{world::WorldStorage, model::{ModelStorage, Model}, event::EventStorage};
use crate::{combat::{CombatState, Phase}, attacks::results::{AttackResult, RoundResult}};
use crate::erc721::ERC721Token;
use super::components::{ConsecutiveWins, ConsecutiveTokenWins};


#[generate_trait]
impl CombatImpl of CombatStorage {
    fn new_combat_state(ref self: WorldStorage, id: felt252) {
        self.write_model(@CombatState { id, phase: Phase::Created, round: 1 });
    }
    fn new_started_combat_state(ref self: WorldStorage, id: felt252) {
        self.write_model(@CombatState { id, phase: Phase::Commit, round: 1 });
    }
    fn get_combat_state(self: @WorldStorage, id: felt252) -> CombatState {
        self.read_model(id)
    }
    fn set_combat_state(ref self: WorldStorage, state: CombatState) {
        self.write_model(@state);
    }
    fn get_combat_round(self: @WorldStorage, id: felt252) -> u32 {
        self.read_member(Model::<CombatState>::ptr_from_keys(id), selector!("round"))
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
            _ => panic!("Combat not ended"),
        }
    }
    fn set_combat_winner(ref self: WorldStorage, id: felt252, winner: felt252) {
        self.set_combat_phase(id, Phase::Ended(winner));
    }

    fn emit_round_result(
        ref self: WorldStorage, combat_id: felt252, round: u32, attacks: Span<AttackResult>,
    ) {
        self.emit_event(@RoundResult { combat_id, round, attacks: attacks });
    }


    fn get_combat_consecutive_wins(
        self: @WorldStorage, player: ContractAddress,
    ) -> ConsecutiveWins {
        self.read_model(player)
    }


    fn set_combat_consecutive_wins(ref self: WorldStorage, model: ConsecutiveWins) {
        self.write_model(@model);
    }


    fn set_combat_current_consecutive_wins(
        ref self: WorldStorage, player: ContractAddress, current: u64,
    ) {
        self
            .write_member(
                Model::<ConsecutiveWins>::ptr_from_keys(player), selector!("current"), current,
            );
    }

    fn reset_combat_current_consecutive_wins(ref self: WorldStorage, player: ContractAddress) {
        let max_wins: u64 = self
            .read_member(Model::<ConsecutiveWins>::ptr_from_keys(player), selector!("max"));
        if max_wins.is_non_zero() {
            self.set_combat_current_consecutive_wins(player, 0);
        }
    }

    fn get_combat_consecutive_token_wins(
        self: @WorldStorage, player: ContractAddress, token: ERC721Token,
    ) -> ConsecutiveTokenWins {
        self.read_model((player, token))
    }

    fn set_combat_consecutive_token_wins(
        ref self: WorldStorage, player: ContractAddress, token: ERC721Token, wins: u64,
    ) {
        self.write_model(@ConsecutiveTokenWins { player, token, current: wins, max: wins });
    }

    fn set_combat_current_consecutive_token_wins(
        ref self: WorldStorage, player: ContractAddress, token: ERC721Token, current: u64,
    ) {
        self
            .write_member(
                Model::<ConsecutiveTokenWins>::ptr_from_keys((player, token)),
                selector!("current"),
                current,
            );
    }

    fn reset_combat_current_consecutive_token_wins(
        ref self: WorldStorage, player: ContractAddress, token: ERC721Token,
    ) {
        let max_wins: u64 = self
            .read_member(
                Model::<ConsecutiveTokenWins>::ptr_from_keys((player, token)), selector!("max"),
            );
        if max_wins.is_non_zero() {
            self.set_combat_current_consecutive_token_wins(player, token, 0);
        }
    }
}
