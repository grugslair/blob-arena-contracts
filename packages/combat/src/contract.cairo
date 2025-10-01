use ba_loadout::attack::IAttackDispatcher;
use ba_utils::{ExternalCalls, Randomness};
use starknet::ClassHash;
use crate::{CombatantState, RoundResult};

#[starknet::contract]
mod combat {
    use ba_loadout::attack::IAttackDispatcher;
    use ba_utils::Randomness;
    use crate::{CombatTrait, CombatantState, RoundResult};

    #[storage]
    struct Storage {}
    fn run_round(
        ref ContractState: ContractState,
        id: felt252,
        round: u32,
        state_1: CombatantState,
        state_2: CombatantState,
        attack_1: felt252,
        attack_2: felt252,
        run_cooldown_1: bool,
        run_cooldown_2: bool,
        attack_dispatcher: IAttackDispatcher,
        randomness: Randomness,
    ) -> (RoundResult, Randomness) {
        let mut combat = CombatTrait::new(
            id, round, state_1, state_2, attack_1, attack_2, randomness, attack_dispatcher,
        );
        combat.run_round(run_cooldown_1, run_cooldown_2);
        combat.to_round_and_randomness()
    }
}


pub fn library_run_round(
    class_hash: ClassHash,
    id: felt252,
    round: u32,
    state_1: CombatantState,
    state_2: CombatantState,
    attack_1: felt252,
    attack_2: felt252,
    run_cooldown_1: bool,
    run_cooldown_2: bool,
    attack_dispatcher: IAttackDispatcher,
    randomness: Randomness,
) -> (RoundResult, Randomness) {
    class_hash
        .call_library(
            selector!("run_round"),
            (
                id,
                round,
                state_1,
                state_2,
                attack_1,
                attack_2,
                run_cooldown_1,
                run_cooldown_2,
                attack_dispatcher,
                randomness,
            ),
        )
}
