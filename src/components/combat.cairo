use core::array::ArrayTrait;
use core::{
    fmt::{Display, Formatter, Error}, hash::{HashStateTrait, HashStateExTrait, Hash},
    poseidon::{poseidon_hash_span, PoseidonTrait, HashState}
};
use starknet::{ContractAddress, get_block_number};
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};
use blob_arena::{
    components::{utils::{ABT, Status, Winner}},
    models::{SaltsModel, Phase, AttackHit, AttackResult, CombatState, PlannedAttack}
};
type Salts = Array<felt252>;

#[generate_trait]
impl SaltsImpl of SaltsTrait {
    fn get_salts_model(self: IWorldDispatcher, id: u128) -> SaltsModel {
        get!(self, id, SaltsModel)
    }

    fn append_salt(self: IWorldDispatcher, id: u128, salt: felt252) {
        let mut model = self.get_salts_model(id);
        model.salts.append(salt);
        set!(self, (model,));
    }

    fn reset_salts(self: IWorldDispatcher, id: u128) {
        set!(self, (SaltsModel { id, salts: ArrayTrait::new(), },));
    }
    fn get_salts(self: IWorldDispatcher, id: u128) -> Salts {
        self.get_salts_model(id).salts
    }


    fn get_salts_hash(self: IWorldDispatcher, id: u128) -> felt252 {
        let model = self.get_salts_model(id);
        poseidon_hash_span(model.salts.span())
    }

    fn get_salts_hash_state(self: IWorldDispatcher, id: u128) -> HashState {
        let salts = self.get_salts_model(id).salts;
        let (mut n, len) = (0, salts.len());
        let mut hash_state = PoseidonTrait::new();
        while n < len {
            hash_state.update(*salts.at(n));
            n += 1;
        };
        hash_state
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
    fn get_combat_state(self: @IWorldDispatcher, id: u128) -> CombatState {
        get!((*self), id, CombatState)
    }
    fn new_combat_state(self: IWorldDispatcher, combat_id: u128) {
        set!(
            self,
            CombatState {
                id: combat_id, phase: Phase::Commit, round: 1, block_number: get_block_number()
            },
        );
    }
    fn get_combat_phase(self: @IWorldDispatcher, id: u128) -> Phase {
        self.get_combat_state(id).phase
    }
    fn next_round(self: IWorldDispatcher, mut state: CombatState) {
        state.round += 1;
        state.phase = Phase::Commit;

        set!(self, (state,));
    }
}

#[generate_trait]
impl PlannedAttackImpl of PlannedAttackTrait {
    fn get_planned_attack(self: @IWorldDispatcher, id: u128) -> PlannedAttack {
        get!((*self), id, PlannedAttack)
    }
    fn get_planned_attacks(self: @IWorldDispatcher, ids: Span<u128>) -> Span<PlannedAttack> {
        let (mut n, len) = (0, ids.len());
        let mut attacks = ArrayTrait::<PlannedAttack>::new();
        while n < len {
            attacks.append(self.get_planned_attack(*ids.at(n)));
            n += 1;
        };
        attacks.span()
    }

    fn check_all_set(self: Span<PlannedAttack>) -> bool {
        let (mut n, len) = (0, self.len());
        let mut set = true;
        while n < len {
            if (*self.at(n).attack).is_zero() {
                set = false;
                break;
            }
            n += 1;
        };
        set
    }

    fn clear_planned_attack(self: IWorldDispatcher, id: u128) {
        set!(self, (PlannedAttack { id, attack: 0, target: 0 },));
    }
    fn clear_planned_attacks(self: IWorldDispatcher, ids: Span<u128>) {
        let (mut n, len) = (0, ids.len());
        while n < len {
            self.clear_planned_attack(*ids.at(n));
            n += 1;
        };
    }
}

