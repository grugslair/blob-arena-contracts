use ba_loadout::action::effect::Duration;
use ba_loadout::action::{Affect, Effect, IActionDispatcher, IActionDispatcherTrait, Recipient};
use ba_utils::storage::{read_at_address, write_at_address};
use ba_utils::{Randomness, RandomnessTrait};
use core::num::traits::Zero;
use cubit::f64::ops::round;
use sai_core_utils::poseidon_hash_three;
use sai_packing::shifts::{SHIFT_4B, SHIFT_4B_FELT252};
use sai_packing::{MaskDowncast, ShiftCast};
use starknet::StorageAddress;
use starknet::storage_access::StorePacking;
use crate::result::{ActionResult, AffectResult, EffectResult, RoundEffectResult};
use crate::round_effect::{RoundEffect, RoundEffects, RoundEffectsTrait};
use crate::{CombatantState, CombatantStateTrait};

#[derive(Copy, Drop, PartialEq, Introspect, Serde, Default, starknet::Store)]
pub enum CombatProgress {
    #[default]
    None,
    Active,
    Ended: Player,
}

const PLAYER_1_ATTACK_STORAGE_ADDRESS: felt252 = selector!("player-1-actions");
const PLAYER_2_ATTACK_STORAGE_ADDRESS: felt252 = selector!("player-2-actions");
const ATTACK_AVAILABLE_BIT: felt252 = SHIFT_4B_FELT252;


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
    pub action_1: felt252,
    pub action_2: felt252,
    pub attach_check_1: ActionCheck,
    pub attach_check_2: ActionCheck,
    pub action_dispatcher: IActionDispatcher,
    pub action_results: Array<ActionResult>,
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

#[derive(Drop, Serde, Copy, PartialEq)]
pub enum ActionCheck {
    None,
    Cooldown: bool,
    Available: bool,
    All,
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
    fn target(self: Player, target: Recipient) -> Player {
        match target {
            Recipient::Actor => self,
            Recipient::Target => !self,
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

pub fn set_actions_available(combat_id: felt252, player: Player, actions: Span<felt252>) {
    let action_storage = match player {
        Player::Player1 => PLAYER_1_ATTACK_STORAGE_ADDRESS,
        Player::Player2 => PLAYER_2_ATTACK_STORAGE_ADDRESS,
    };
    for action_id in actions {
        let storage_address: StorageAddress = poseidon_hash_three(
            combat_id, action_storage, *action_id,
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
        action_1: felt252,
        action_2: felt252,
        attach_check_1: ActionCheck,
        attach_check_2: ActionCheck,
        randomness: Randomness,
        action_dispatcher: IActionDispatcher,
    ) -> Combat {
        Combat {
            id,
            state_1,
            state_2,
            first: None,
            round_effects: RoundEffectsTrait::new(id, round),
            round,
            action_1,
            action_2,
            attach_check_1,
            attach_check_2,
            progress: CombatProgress::Active,
            randomness,
            action_dispatcher,
            action_results: Default::default(),
            round_effect_results: Default::default(),
        }
    }


    fn apply_affect(
        ref self: Combat, source: Player, target: Player, affect: Affect,
    ) -> EffectResult {
        let actor_state = self.get_actor_state(source);
        let affect = match target {
            Player::Player1 => self.state_1.apply_affect(affect, actor_state, ref self.randomness),
            Player::Player2 => self.state_2.apply_affect(affect, actor_state, ref self.randomness),
        };
        EffectResult { target, affect }
    }

    fn get_actor_state(self: @Combat, player: Player) -> @CombatantState {
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

    fn set_actions(ref self: Combat, action_1: felt252, action_2: felt252) {
        self.action_1 = action_1;
        self.action_2 = action_2;
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
        ref self: Combat, source: Player, effects: Array<Effect>,
    ) -> Array<EffectResult> {
        let mut results: Array<EffectResult> = ArrayTrait::new();
        for effect in effects {
            results.append(self.apply_effect(source, effect));
        }
        results
    }

    fn action_dispatcher(self: @Combat) -> @IActionDispatcher {
        self.action_dispatcher
    }

    fn get_action_id_and_storage(self: @Combat, player: Player) -> (felt252, StorageAddress) {
        let (action_id, action_storage) = match player {
            Player::Player1 => (*self.action_1, PLAYER_1_ATTACK_STORAGE_ADDRESS),
            Player::Player2 => (*self.action_2, PLAYER_2_ATTACK_STORAGE_ADDRESS),
        };
        let storage_address: StorageAddress = poseidon_hash_three(
            *self.id, action_storage, action_id,
        )
            .try_into()
            .unwrap();
        (action_id, storage_address)
    }
    fn check_action_available(self: @Combat, player: Player) -> felt252 {
        let (action_id, storage_address) = self.get_action_id_and_storage(player);
        ShiftCast::<u64>::const_unpack::<SHIFT_4B>(read_at_address(storage_address)).into()
            * action_id
    }
    fn run_action_cooldown(ref self: Combat, player: Player, available: bool) -> felt252 {
        let (action_id, storage_address) = self.get_action_id_and_storage(player);
        let round_available = read_at_address(storage_address);
        let last_used: u32 = MaskDowncast::cast(round_available);
        if available || ShiftCast::<u8>::const_unpack::<SHIFT_4B>(round_available).is_non_zero() {
            let round = self.round;
            let cooldown = self.action_dispatcher().cooldown(action_id);
            if cooldown.is_zero() {
                return action_id;
            } else if last_used.is_zero() || ((cooldown.into() + last_used) < round) {
                write_at_address(storage_address, round.into() + ATTACK_AVAILABLE_BIT);
                return action_id;
            }
        }
        return 0;
    }
    fn action_id(self: @Combat, player: Player) -> felt252 {
        match player {
            Player::Player1 => *self.action_1,
            Player::Player2 => *self.action_2,
        }
    }
    fn action_check(self: @Combat, player: Player) -> ActionCheck {
        match player {
            Player::Player1 => *self.attach_check_1,
            Player::Player2 => *self.attach_check_2,
        }
    }
    fn run_action_check(ref self: Combat, player: Player) -> felt252 {
        let action_check = self.action_check(player);
        match action_check {
            ActionCheck::None => self.action_id(player),
            ActionCheck::Cooldown(available) => match available {
                true => self.run_action_cooldown(player, true),
                false => 0x0,
            },
            ActionCheck::Available(cooldown) => match cooldown {
                true => self.check_action_available(player),
                false => 0x0,
            },
            ActionCheck::All => { self.run_action_cooldown(player, false) },
        }
    }

    fn run_stun(ref self: Combat, player: Player) -> bool {
        match player {
            Player::Player1 => self.state_1.run_stun(ref self.randomness),
            Player::Player2 => self.state_2.run_stun(ref self.randomness),
        }
    }

    fn get_action(self: @Combat, player: Player) -> felt252 {
        match player {
            Player::Player1 => *self.action_1,
            Player::Player2 => *self.action_2,
        }
    }

    fn run_action(ref self: Combat, source: Player) {
        let action_id = self.run_action_check(source);
        let result = if action_id.is_zero() {
            ActionResult::NotAvailable
        } else if self.run_stun(source) {
            ActionResult::Stunned
        } else {
            let (n, effect) = self
                .action_dispatcher
                .get_effects(action_id, self.randomness.get(1_000_000));
            ActionResult::Action((n, self.apply_effects(source, effect)))
        };
        self.action_results.append(result);
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

    fn get_first_player(ref self: Combat) -> Option<Player> {
        let speed_1 = self.action_dispatcher.speed(self.action_1) + (self.state_1.dexterity).into();
        let speed_2 = self.action_dispatcher.speed(self.action_2) + (self.state_2.dexterity).into();
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
        self.first
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
            actions: [self.action_1, self.action_2],
            first: self.first.into(),
            states: [self.state_1, self.state_2],
            round_effect_results: self.round_effect_results,
            action_results: self.action_results,
            progress: self.progress,
        }
    }

    fn to_round_and_randomness(self: Combat) -> (RoundResult, Randomness) {
        (
            RoundResult {
                combat: self.id,
                round: self.round,
                actions: [self.action_1, self.action_2],
                first: self.first.into(),
                states: [self.state_1, self.state_2],
                round_effect_results: self.round_effect_results,
                action_results: self.action_results,
                progress: self.progress,
            },
            self.randomness,
        )
    }

    fn run_round(ref self: Combat) {
        self.run_round_effects();

        if self.progress == CombatProgress::Active {
            let first = self.get_first_player().unwrap();
            self.run_action(first);
            if self.progress == CombatProgress::Active {
                self.run_action(!first);
            }
        }
    }
}


#[derive(Drop, Serde, Introspect)]
pub struct RoundResult {
    pub combat: felt252,
    pub round: u32,
    pub states: [CombatantState; 2],
    pub actions: [felt252; 2],
    pub first: PlayerOrNone,
    pub round_effect_results: Array<RoundEffectResult>,
    pub action_results: Array<ActionResult>,
    pub progress: CombatProgress,
}

#[derive(Drop, Serde, Schema)]
pub struct RoundZeroResult {
    pub combat: felt252,
    pub states: [CombatantState; 2],
    pub progress: CombatProgress,
}


#[starknet::contract]
pub mod round_result_model {
    use super::RoundResult;
    #[storage]
    struct Storage {}
    #[abi(embed_v0)]
    impl RoundResultModelImpl =
        beacon_entity::interface::ISaiModelImpl<ContractState, RoundResult>;
}


#[cfg(test)]
mod tests {
    use beacon_entity::get_schema_size;
    use super::*;

    #[derive(Drop, Serde, Introspect)]
    struct AnAffect {
        affect: Affect,
    }
    #[test]
    fn table_size_test() {
        println!("RoundResult size: {}", get_schema_size::<RoundResult>());
    }
}
