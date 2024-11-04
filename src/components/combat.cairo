use core::{
    fmt::{Display, Formatter, Error}, hash::{HashStateTrait, HashStateExTrait, Hash},
    poseidon::{poseidon_hash_span, PoseidonTrait, HashState}
};
use starknet::{ContractAddress, get_block_number};
use dojo::{world::{WorldStorage, ModelStorage}, model::Model};
use blob_arena::{
    components::{utils::{ABT, Status, Winner}, commitment::Commitment},
    models::{
        SaltsModel, Phase, CombatState, CombatStateStore, PlannedAttack, PlannedAttackStore,
        CombatantState
    },
    hash::ArrayHash
};
type Salts = Array<felt252>;

#[generate_trait]
impl SaltsImpl of SaltsTrait {
    fn get_salts_model(ref self: WorldStorage, id: felt252) -> SaltsModel {
        get!(self, id, SaltsModel)
    }

    fn set_salts(ref self: WorldStorage, id: felt252, salts: Salts) {
        set!(self, (SaltsModel { id, salts: salts },));
    }

    fn append_salt(ref self: WorldStorage, id: felt252, salt: felt252) {
        let mut salts = self.get_salts(id);
        salts.append(salt);
        self.set_salts(id, salts);
    }

    fn reset_salts(ref self: WorldStorage, id: felt252) {
        set!(self, (SaltsModel { id, salts: array![] }));
    }
    fn get_salts(ref self: WorldStorage, id: felt252) -> Salts {
        self.get_salts_model(id).salts
    }


    fn get_salts_hash(ref self: WorldStorage, id: felt252) -> felt252 {
        poseidon_hash_span(self.get_salts(id).span())
    }

    fn get_salts_hash_state(ref self: WorldStorage, id: felt252) -> HashState {
        PoseidonTrait::new().update_with(self.get_salts(id))
    }
}

#[generate_trait]
impl PhaseImpl of PhaseTrait {
    fn assert_running(self: @Phase) {
        assert(self.is_running(), 'Combat not running')
    }
    fn is_running(self: @Phase) -> bool {
        match *self {
            Phase::Commit | Phase::Reveal => true,
            _ => false
        }
    }
}

#[generate_trait]
impl CombatStateImpl of CombatStateTrait {
    fn get_combat_state(self: @WorldStorage, id: felt252) -> CombatState {
        CombatStateStore::get(*self, id)
    }
    fn new_combat_state(ref self: WorldStorage, id: felt252) {
        CombatState { id, phase: Phase::Commit, round: 1, block_number: get_block_number() }
            .set(self)
    }
    fn get_combat_phase(self: @WorldStorage, id: felt252) -> Phase {
        self.get_combat_state(id).phase
    }
    fn get_running_combat_state(self: @WorldStorage, id: felt252) -> CombatState {
        let state = self.get_combat_state(id);
        state.phase.assert_running();
        state
    }
    fn next_round(ref self: WorldStorage, mut state: CombatState, combatants: Span<felt252>) {
        self.reset_salts(state.id);
        self.clear_commitments_with(combatants);
        self.clear_planned_attacks(combatants);
        state.round += 1;
        state.phase = Phase::Commit;
        state.set(self);
    }
}
#[generate_trait]
impl CombatStatesImpl of CombatStatesTrait {
    fn get_combatants_mortality(
        mut self: Array<CombatantState>
    ) -> (Array<felt252>, Array<felt252>) {
        let mut alive = ArrayTrait::<felt252>::new();
        let mut dead = ArrayTrait::<felt252>::new();
        loop {
            match self.pop_front() {
                Option::Some(state) => {
                    if state.health.is_non_zero() {
                        alive.append(state.id);
                    } else {
                        dead.append(state.id);
                    }
                },
                Option::None => { break; }
            }
        };
        (alive, dead)
    }
    fn end_combat(ref self: WorldStorage, mut state: CombatState, winner: felt252) {
        state.phase = Phase::Ended(winner);
        state.set(self);
    }
}


#[generate_trait]
impl PlannedAttackImpl of PlannedAttackTrait {
    fn get_planned_attack(self: @WorldStorage, id: felt252) -> PlannedAttack {
        PlannedAttackStore::get(*self, id)
    }
    fn get_planned_attacks(self: @WorldStorage, mut ids: Span<felt252>) -> Span<PlannedAttack> {
        let mut attacks = ArrayTrait::<PlannedAttack>::new();
        loop {
            match ids.pop_front() {
                Option::Some(id) => { attacks.append(self.get_planned_attack(*id)); },
                Option::None => { break attacks.span(); },
            }
        }
    }
    fn set_planned_attack(ref self: WorldStorage, attack: PlannedAttack) {
        attack.set(self)
    }
}

