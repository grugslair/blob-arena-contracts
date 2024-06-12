use core::{hash::HashStateTrait, poseidon::{PoseidonTrait, HashState},};
use alexandria_math::BitShift;
use blob_arena::{
    core::{LimitSub, LimitAdd},
    components::{
        combat::{Phase}, combatant::{Combatant, CombatantTrait}, attack::{Attack},
        utils::{AB, ABT, ABTTrait}
    },
    systems::{attack::AttackSystemTrait, combat::{AttackResult, CombatWorld, CombatSystem}},
};
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};


struct PvPCombatWorld {
    world: IWorldDispatcher,
    combat: CombatWorld,
    combatants: ABT<Combatant>,
}


#[generate_trait]
impl PvPCombatSystemImpl of PvPCombatSystemTrait {
    fn run_round(
        self: @CombatWorld, combatants: ABT<Combatant>, attacks: ABT<Attack>, hash: HashState
    ) -> (ABT<Combatant>, ABT<AttackResult>) {
        let speed_a = attacks.a.speed + combatants.a.stats.speed;
        let speed_b = attacks.b.speed + combatants.b.stats.speed;
        let first = if speed_a > speed_b {
            AB::A
        } else if speed_a < speed_b {
            AB::B
        } else {
            (hash.finalize().try_into().unwrap() % 2_u128).into()
        };
        let mut combatant_1 = combatants.get(first);
        let mut combatant_2 = combatants.get(!first);
        let attack_1 = attacks.get(first);
        let attack_2 = attacks.get(!first);
        let result_1 = self.run_attack(ref combatant_1, ref combatant_2, attack_1, hash);
        let result_2 = self.run_attack(ref combatant_2, ref combatant_1, attack_2, hash);
        match first {
            AB::A => (ABTTrait::new(combatant_1, combatant_2), ABTTrait::new(result_1, result_2)),
            AB::B => (ABTTrait::new(combatant_2, combatant_1), ABTTrait::new(result_2, result_1)),
        }
    }

    fn end_game(ref self: CombatWorld, winner: AB) {
        self.phase = Phase::Ended;
    }
}
