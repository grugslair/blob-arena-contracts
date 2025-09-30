use ba_loadout::attack::effect::Duration;
use ba_loadout::attack::{Affect, Effect, IAttackDispatcher, IAttackDispatcherTrait, Target};
use ba_utils::storage::{read_at_address, write_at_address};
use ba_utils::{Randomness, RandomnessTrait};
use core::num::traits::Zero;
use cubit::f64::ops::round;
use sai_core_utils::{BoolIntoBinary, poseidon_hash_three};
use sai_packing::MaskDowncast;
use sai_packing::shifts::SHIFT_4B_FELT252;
use starknet::StorageAddress;
use starknet::storage_access::StorePacking;
use crate::result::{AffectResult, AttackResult, EffectResult, RoundEffectResult};
use crate::round_effect::{RoundEffect, RoundEffects, RoundEffectsTrait};
use crate::{CombatantState, CombatantStateTrait};

#[derive(Copy, Drop, PartialEq, Introspect, Serde, Default, starknet::Store)]
pub enum CombatProgress {
    #[default]
    None,
    Active,
    Ended: Player,
}

const PLAYER_1_ATTACK_STORAGE_ADDRESS: felt252 = selector!("player-1-attacks");
const PLAYER_2_ATTACK_STORAGE_ADDRESS: felt252 = selector!("player-2-attacks");
const ATTACK_AVAILABLE_BIT: felt252 = SHIFT_4B_FELT252;

// const PLAYER_1_PACKING_BITS: u64 = SHIFT_4B_U64 * 1;
// const PLAYER_2_PACKING_BITS: u64 = SHIFT_4B_U64 * 2;

// #[derive(Drop, PartialEq, Introspect, Default)]
// struct CombatState {
//     pub round: u32,
//     pub progress: CombatProgress,
// }

// impl CombatStateStoragePacking of StorePacking<CombatState, u64> {
//     fn pack(value: CombatState) -> u64 {
//         value.round.into()
//             + match value.progress {
//                 CombatProgress::Active => 0_u64,
//                 CombatProgress::Ended(Player::Player1) => PLAYER_1_PACKING_BITS,
//                 CombatProgress::Ended(Player::Player2) => PLAYER_2_PACKING_BITS,
//             }
//     }

//     fn unpack(value: u64) -> CombatState {
//         let round: u32 = MaskDowncast::cast(value);
//         let progress = match ShiftCast::const_unpack::<SHIFT_4B>(value) {
//             0_u8 => CombatProgress::Active,
//             1_u8 => CombatProgress::Ended(Player::Player1),
//             2_u8 => CombatProgress::Ended(Player::Player2),
//             _ => panic!("Invalid value for CombatProgress"),
//         };
//         CombatState { round, progress }
//     }
// }

#[derive(Destruct)]
pub struct Combat {
    pub id: felt252,
    pub first: Option<Player>,
    pub state_1: CombatantState,
    pub state_2: CombatantState,
    pub round_effects: RoundEffects,
    pub round: u32,
    pub progress: CombatProgress,
    pub randomness: Randomness,
    pub attack_1: felt252,
    pub attack_2: felt252,
    pub attack_dispatcher: IAttackDispatcher,
    pub attack_results: Array<AttackResult>,
    pub round_effect_results: Array<RoundEffectResult>,
}

impl BoolIntoPlayer of Into<bool, Player> {
    fn into(self: bool) -> Player {
        match self {
            false => Player::Player1,
            true => Player::Player2,
        }
    }
}

#[allow(starknet::store_no_default_variant)]
#[derive(Copy, Drop, Serde, PartialEq, Introspect, starknet::Store)]
pub enum Player {
    Player1,
    Player2,
}

#[derive(Copy, Drop, Serde, PartialEq, Introspect, starknet::Store)]
pub enum PlayerOrNone {
    #[default]
    None,
    Player1,
    Player2,
}

impl OptionPlayerStoragePacking of StorePacking<Option<Player>, u32> {
    fn pack(value: Option<Player>) -> u32 {
        match value {
            None => 0_u32,
            Some(Player::Player1) => 1_u32,
            Some(Player::Player2) => 2_u32,
        }
    }

    fn unpack(value: u32) -> Option<Player> {
        match value {
            0 => None,
            1 => Some(Player::Player1),
            2 => Some(Player::Player2),
            _ => panic!("Invalid value for Option<Player>"),
        }
    }
}


impl OptionPlayerIntoPlayerOrNone of Into<Option<Player>, PlayerOrNone> {
    fn into(self: Option<Player>) -> PlayerOrNone {
        match self {
            None => PlayerOrNone::None,
            Some(player) => player.into(),
        }
    }
}

impl PlayerIntoPlayerOrNone of Into<Player, PlayerOrNone> {
    fn into(self: Player) -> PlayerOrNone {
        match self {
            Player::Player1 => PlayerOrNone::Player1,
            Player::Player2 => PlayerOrNone::Player2,
        }
    }
}

#[generate_trait]
impl PlayerImpl of PlayerTrait {
    fn target(self: Player, target: Target) -> Player {
        match target {
            Target::Attacker => self,
            Target::Defender => !self,
        }
    }
}

impl NotPlayer of Not<Player> {
    fn not(a: Player) -> Player {
        match a {
            Player::Player1 => Player::Player2,
            Player::Player2 => Player::Player1,
        }
    }
}

pub fn set_attacks_available(combat_id: felt252, player: Player, attacks: Span<felt252>) {
    let attack_storage = match player {
        Player::Player1 => PLAYER_1_ATTACK_STORAGE_ADDRESS,
        Player::Player2 => PLAYER_2_ATTACK_STORAGE_ADDRESS,
    };
    for attack_id in attacks {
        let storage_address: StorageAddress = poseidon_hash_three(
            combat_id, attack_storage, *attack_id,
        )
            .try_into()
            .unwrap();
        write_at_address(storage_address, ATTACK_AVAILABLE_BIT);
    }
}

#[generate_trait]
pub impl CombatImpl of CombatTrait {
    fn new(
        id: felt252,
        round: u32,
        state_1: CombatantState,
        state_2: CombatantState,
        randomness: Randomness,
        attack_dispatcher: IAttackDispatcher,
    ) -> Combat {
        Combat {
            id,
            state_1,
            state_2,
            first: None,
            round_effects: RoundEffectsTrait::new(id, round),
            round,
            attack_1: 0,
            attack_2: 0,
            progress: CombatProgress::Active,
            randomness,
            attack_dispatcher,
            attack_results: Default::default(),
            round_effect_results: Default::default(),
        }
    }


    fn apply_affect(
        ref self: Combat, source: Player, target: Player, affect: Affect,
    ) -> EffectResult {
        let attacker_state = self.get_attacker_state(source);
        let affect = match target {
            Player::Player1 => self
                .state_1
                .apply_affect(affect, attacker_state, ref self.randomness),
            Player::Player2 => self
                .state_2
                .apply_affect(affect, attacker_state, ref self.randomness),
        };
        EffectResult { target, affect }
    }

    fn get_attacker_state(self: @Combat, player: Player) -> @CombatantState {
        match player {
            Player::Player1 => self.state_1,
            Player::Player2 => self.state_2,
        }
    }

    fn apply_round_effect(
        ref self: Combat, source: Player, target: Player, affect: Affect, round: u32,
    ) {
        self.round_effects.add_effect(RoundEffect { source, target, affect }, round)
    }

    fn apply_infinite_effect(ref self: Combat, source: Player, target: Player, affect: Affect) {
        self.round_effects.add_infinite_effect(RoundEffect { source, target, affect })
    }

    fn set_attacks(ref self: Combat, attack_1: felt252, attack_2: felt252) {
        self.attack_1 = attack_1;
        self.attack_2 = attack_2;
    }

    fn apply_effect(ref self: Combat, source: Player, effect: Effect) -> EffectResult {
        let Effect { duration, target, affect } = effect;
        let target = source.target(target);
        match duration {
            Duration::Instant => self.apply_affect(source, target, affect),
            Duration::Round(round) => {
                self.apply_round_effect(source, target, affect, round);
                EffectResult { target, affect: AffectResult::Applied }
            },
            Duration::Rounds(count) => {
                for round in 1..(count + 1) {
                    self.apply_round_effect(source, target, affect, round);
                }
                EffectResult { target, affect: AffectResult::Applied }
            },
            Duration::Infinite => {
                self.apply_infinite_effect(source, target, affect);
                EffectResult { target, affect: AffectResult::Applied }
            },
        }
    }

    fn apply_effects(
        ref self: Combat, attacker: Player, effects: Array<Effect>,
    ) -> Array<EffectResult> {
        let mut results: Array<EffectResult> = ArrayTrait::new();
        for effect in effects {
            results.append(self.apply_effect(attacker, effect));
        }
        results
    }

    fn get_attack_useage(self: @Combat, player: Player) -> (felt252, bool, u32, StorageAddress) {
        let (attack_id, attack_storage) = match player {
            Player::Player1 => (*self.attack_1, PLAYER_1_ATTACK_STORAGE_ADDRESS),
            Player::Player2 => (*self.attack_2, PLAYER_2_ATTACK_STORAGE_ADDRESS),
        };
        let storage_address: StorageAddress = poseidon_hash_three(
            *self.id, attack_storage, attack_id,
        )
            .try_into()
            .unwrap();
        let value = read_at_address(storage_address);
        let available = value.is_non_zero();
        let last_used: u32 = MaskDowncast::cast(value);
        (attack_id, available, last_used, storage_address)
    }

    fn attack_dispatcher(self: @Combat) -> @IAttackDispatcher {
        self.attack_dispatcher
    }

    fn run_attack_cooldown(ref self: Combat, player: Player) {
        let (attack_id, available, last_used, storage_address) = self.get_attack_useage(player);
        let round = self.round;
        if available {
            let cooldown = self.attack_dispatcher().cooldown(attack_id);
            if cooldown.is_zero() {
                return;
            } else if last_used.is_zero() || ((cooldown.into() + last_used) < round) {
                write_at_address(storage_address, round.into() + ATTACK_AVAILABLE_BIT);
                return;
            }
        }
        match player {
            Player::Player1 => { self.attack_1 = 0; },
            Player::Player2 => { self.attack_2 = 0; },
        };
    }

    fn run_attack_cooldowns(ref self: Combat) {
        self.run_attack_cooldown(Player::Player1);
        self.run_attack_cooldown(Player::Player2);
    }

    fn run_stun(ref self: Combat, player: Player) -> bool {
        match player {
            Player::Player1 => self.state_1.run_stun(ref self.randomness),
            Player::Player2 => self.state_2.run_stun(ref self.randomness),
        }
    }

    fn get_attack(self: @Combat, player: Player) -> felt252 {
        match player {
            Player::Player1 => *self.attack_1,
            Player::Player2 => *self.attack_2,
        }
    }

    fn run_attack(ref self: Combat, source: Player) {
        let attack_id = self.get_attack(source);
        let result = if attack_id.is_zero() {
            AttackResult::Failed
        } else if self.run_stun(source) {
            AttackResult::Stunned
        } else if self.randomness.get(100) < self.attack_dispatcher.chance(attack_id) {
            AttackResult::Success(
                self.apply_effects(source, self.attack_dispatcher.success(attack_id)),
            )
        } else {
            AttackResult::Fail(self.apply_effects(source, self.attack_dispatcher.fail(attack_id)))
        };
        self.attack_results.append(result);
        self.check_progress(!source);
    }

    fn check_progress(ref self: Combat, advantage: Player) {
        self
            .progress =
                if self.state_1.health.is_non_zero() && self.state_2.health.is_non_zero() {
                    CombatProgress::Active
                } else if self.state_1.health.is_non_zero() {
                    CombatProgress::Ended(Player::Player1)
                } else if self.state_2.health.is_non_zero() {
                    CombatProgress::Ended(Player::Player2)
                } else {
                    CombatProgress::Ended(advantage) // Both dead, Player 1 wins by default
                };
    }

    fn get_first_player(ref self: Combat) {
        let speed_1 = self.attack_dispatcher.speed(self.attack_1) + (self.state_1.dexterity).into();
        let speed_2 = self.attack_dispatcher.speed(self.attack_2) + (self.state_2.dexterity).into();
        self
            .first =
                Some(
                    if speed_1 == speed_2 {
                        self.randomness.get_bool()
                    } else {
                        speed_1 < speed_2
                    }
                        .into(),
                );
    }

    fn run_round_effects(ref self: Combat) -> CombatProgress {
        let mut phase: CombatProgress = Default::default();
        for effect in (@self.round_effects).into_iter() {
            self.apply_affect(effect.source, effect.target, effect.affect);
            self.check_progress(!effect.source);
            if self.progress != CombatProgress::Active {
                return phase;
            }
        }
        phase
    }

    fn states(self: @Combat) -> [CombatantState; 2] {
        [*self.state_1, *self.state_2]
    }


    fn to_round(self: Combat) -> RoundResult {
        RoundResult {
            combat: self.id,
            round: self.round,
            attacks: [self.attack_1, self.attack_2],
            first: self.first.into(),
            states: [self.state_1, self.state_2],
            round_effects_results: self.round_effect_results,
            attack_results: self.attack_results,
            progress: self.progress,
        }
    }

    fn run_round(ref self: Combat) {
        self.run_round_effects();
        if self.progress == CombatProgress::Active {
            self.get_first_player();
            let first = self.first.unwrap();
            self.run_attack(first);
            if self.progress == CombatProgress::Active {
                self.run_attack(!first);
            }
        }
    }
}


#[derive(Drop, Serde, Introspect)]
pub struct RoundResult {
    pub combat: felt252,
    pub round: u32,
    pub states: [CombatantState; 2],
    pub attacks: [felt252; 2],
    pub first: PlayerOrNone,
    pub round_effects_results: Array<RoundEffectResult>,
    pub attack_results: Array<AttackResult>,
    pub progress: CombatProgress,
}

#[derive(Drop, Serde, Schema)]
pub struct RoundZeroResult {
    pub combat: felt252,
    pub states: [CombatantState; 2],
    pub progress: CombatProgress,
}
