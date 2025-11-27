use ba_combat::combat::{CombatProgress, Player};
use ba_combat::combatant::CombatantState;
use ba_loadout::Attributes;
use ba_loadout::action::{IActionDispatcher, IActionDispatcherTrait};
use ba_loadout::attributes::Abilities;
use ba_utils::{Randomness, RandomnessTrait};
use core::num::traits::Zero;
use starknet::storage::{
    Map, Mutable, MutableVecTrait, StorageMapReadAccess, StorageMapWriteAccess, StoragePath,
    StoragePointerReadAccess, StoragePointerWriteAccess, Vec,
};
use starknet::{ContractAddress, get_block_timestamp, get_caller_address};

pub type CombatNodePath = StoragePath<Mutable<CombatNode>>;
pub type AttemptNodePath = StoragePath<Mutable<AttemptNode>>;


/// Represents the current phase of an arcade attempt.
//// * `None` - The attempt has not started.
/// * `Active` - The attempt is currently active.
/// * `PlayerWon` - The player has won the attempt.
/// * `PlayerLost` - The player has lost the attempt.
#[derive(Drop, Copy, Introspect, PartialEq, Serde, starknet::Store, Default)]
pub enum ArcadeProgress {
    #[default]
    None,
    Active,
    PlayerWon,
    PlayerLost,
}

impl CombatProgressIntoArcadePhase of Into<CombatProgress, ArcadeProgress> {
    fn into(self: CombatProgress) -> ArcadeProgress {
        match self {
            CombatProgress::None => ArcadeProgress::None,
            CombatProgress::Active => ArcadeProgress::Active,
            CombatProgress::Ended(player) => match player {
                Player::Player1 => ArcadeProgress::PlayerWon,
                Player::Player2 => ArcadeProgress::PlayerLost,
            },
        }
    }
}


/// Represents an arcade attempt by a player.
//// # Fields
/// * `player` - The address of the player making the attempt.
/// * `abilities` - The abilities of the player during the attempt.
/// * `token_hash` - A hash representing the player's token.
/// * `health_regen` - The health regeneration amount.
/// * `expiry` - The timestamp when the attempt expires.
/// * `phase` - The current phase of the arcade attempt.
/// * `stage` - The current stage of the attempt.
/// * `respawns` - The number of respawns the player has used.
#[derive(Drop, Serde)]
pub struct Attempt {
    pub player: ContractAddress,
    pub abilities: Abilities,
    pub token_hash: felt252,
    pub health_regen: u8,
    pub expiry: u64,
    pub phase: ArcadeProgress,
    pub combat: u32,
    pub respawns: u32,
}

#[starknet::storage_node]
pub struct AttemptNode {
    pub player: ContractAddress,
    pub attributes: Attributes,
    pub token_hash: felt252,
    pub health_regen: u8,
    pub actions_available: Map<felt252, bool>,
    pub orb_uses: u32,
    pub combats: Map<u32, CombatNode>,
    pub expiry: u64,
    pub phase: ArcadeProgress,
    pub stage: u32,
    pub respawns: u32,
}

#[starknet::storage_node]
pub struct CombatNode {
    pub player_state: CombatantState,
    pub opponent_state: CombatantState,
    pub action_last_used: Map<felt252, u32>,
    pub opponent_actions: Vec<(felt252, u32)>,
    pub round: u32,
    pub phase: ArcadeProgress,
}


trait AttemptNodeReadTrait<TState> {
    fn attempt_node(self: @TState, attempt_id: felt252) -> AttemptNodePath;
}


#[generate_trait]
pub impl AttemptNodeImpl of AttemptNodeTrait {
    fn assert_caller_is_owner(ref self: AttemptNodePath) -> ContractAddress {
        let caller = get_caller_address();
        assert(self.player.read() == caller, 'Not Callers Game');
        caller
    }
    fn is_not_expired(ref self: AttemptNodePath) -> bool {
        get_block_timestamp() <= self.expiry.read()
    }
    fn assert_active(ref self: AttemptNodePath) {
        assert(self.phase.read() == ArcadeProgress::Active, 'Attempt is not active');
    }
    fn new_attempt(
        ref self: AttemptNodePath,
        player: ContractAddress,
        attributes: Attributes,
        actions: Array<felt252>,
        token_hash: felt252,
        health_regen: u8,
        expiry: u64,
    ) {
        self.player.write(player);
        self.expiry.write(expiry);
        self.attributes.write(attributes);
        self.token_hash.write(token_hash);
        self.health_regen.write(health_regen);
        for action in actions {
            self.actions_available.write(action, true);
        }
        self.phase.write(ArcadeProgress::Active);
    }

    fn create_combat(
        ref self: StoragePath<Mutable<CombatNode>>,
        player_state: CombatantState,
        opponent_state: CombatantState,
        opponent_actions: Array<felt252>,
    ) {
        self.player_state.write(player_state);
        self.opponent_state.write(opponent_state);
        self.phase.write(ArcadeProgress::Active);
        self.round.write(1);
        for action in opponent_actions {
            if action.is_non_zero() {
                self.opponent_actions.push((action, 0));
            }
        }
    }

    fn get_opponent_action(
        ref self: CombatNodePath,
        actions: IActionDispatcher,
        round: u32,
        ref randomness: Randomness,
    ) -> felt252 {
        let (mut n, n_actions) = (0, self.opponent_actions.len());
        let sn = randomness.get(n_actions);
        loop {
            let mut i = (n + sn);
            if i >= n_actions {
                i -= n_actions
            }
            let (action_id, last_used) = self.opponent_actions.at(i).read();
            let cooldown = actions.cooldown(action_id);
            if cooldown == 0 {
                return action_id;
            }
            if last_used.is_zero() || ((cooldown.into() + last_used) < round) {
                self.opponent_actions.at(i).write((action_id, round));
                return action_id;
            }

            n += 1;
            if n == n_actions {
                break 0;
            };
        }
    }


    fn player_action_cooldown(
        ref self: CombatNodePath, actions: IActionDispatcher, action_id: felt252, round: u32,
    ) -> felt252 {
        let cooldown = actions.cooldown(action_id);
        if cooldown.is_zero() {
            return action_id;
        }
        let last_used = self.action_last_used.read(action_id);
        if last_used.is_zero() || ((cooldown.into() + last_used) < round) {
            self.action_last_used.write(action_id, round);
            return action_id;
        }
        0
    }

    fn combat_n(self: AttemptNodePath) -> u32 {
        self.stage.read() + self.respawns.read()
    }
}

