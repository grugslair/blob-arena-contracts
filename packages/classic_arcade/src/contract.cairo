#[starknet::contract]
mod classic_arcade {
    use starknet::get_caller_address;
    use starknet::storage::{
        Map, MutableVecTrait, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess, VecTrait,
    };
    use crate::component::{ArcadePhase, ArcadeRoundNode, AttemptNode};


    #[storage]
    struct Storage {
        attempts: Map<felt252, AttemptNode>,
    }


    fn attack(ref self: ContractState, attempt_id: felt252, attack_id: felt252) {
        let mut attempt = self.attempts.entry(attempt_id);
        let caller = get_caller_address();
        let randomness = 12;
        assert(attempt.player.read() == caller, 'Not Callers Game');
        assert(attempt.phase.read() == ArcadePhase::Active, 'Game is not active');
        let round_n = attempt.rounds.len();
        let round = attempt.rounds.at(round_n - 1);
    }
}
