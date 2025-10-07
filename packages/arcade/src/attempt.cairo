use ba_combat::combat::{CombatProgress, Player};
use ba_combat::combatant::CombatantState;
use ba_loadout::Attributes;
use ba_loadout::attack::{IAttackDispatcher, IAttackDispatcherTrait};
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


#[derive(Drop, Serde)]
pub struct Attempt {
    pub player: ContractAddress,
    pub abilities: Abilities,
    pub token_hash: felt252,
    pub health_regen: u32,
    pub expiry: u64,
    pub phase: ArcadeProgress,
    pub stage: u32,
    pub respawns: u32,
}

#[starknet::storage_node]
pub struct AttemptNode {
    pub player: ContractAddress,
    pub attributes: Attributes,
    pub token_hash: felt252,
    pub health_regen: u8,
    pub attacks_available: Map<felt252, bool>,
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
    pub attack_last_used: Map<felt252, u32>,
    pub opponent_attacks: Vec<(felt252, u32)>,
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
        attacks: Array<felt252>,
        token_hash: felt252,
        health_regen: u8,
        expiry: u64,
    ) {
        self.player.write(player);
        self.expiry.write(expiry);
        self.attributes.write(attributes);
        self.token_hash.write(token_hash);
        self.health_regen.write(health_regen);
        for attack in attacks {
            self.attacks_available.write(attack, true);
        }
        self.phase.write(ArcadeProgress::Active);
    }

    fn create_combat(
        ref self: StoragePath<Mutable<CombatNode>>,
        player_state: CombatantState,
        opponent_state: CombatantState,
        opponent_attacks: Array<felt252>,
    ) {
        self.player_state.write(player_state);
        self.opponent_state.write(opponent_state);
        self.phase.write(ArcadeProgress::Active);
        self.round.write(1);
        for attack in opponent_attacks {
            if attack.is_non_zero() {
                self.opponent_attacks.push((attack, 0));
            }
        }
    }

    fn get_opponent_attack(
        ref self: CombatNodePath,
        attacks: IAttackDispatcher,
        round: u32,
        ref randomness: Randomness,
    ) -> felt252 {
        let (mut n, n_attacks) = (0, self.opponent_attacks.len());
        let sn = randomness.get(n_attacks);
        loop {
            let mut i = (n + sn);
            if i >= n_attacks {
                i -= n_attacks
            }
            let (attack_id, last_used) = self.opponent_attacks.at(i).read();
            let cooldown = attacks.cooldown(attack_id);
            if cooldown == 0 {
                return attack_id;
            }
            if last_used.is_zero() || ((cooldown.into() + last_used) < round) {
                self.opponent_attacks.at(i).write((attack_id, round));
                return attack_id;
            }

            n += 1;
            if n == n_attacks {
                break 0;
            };
        }
    }


    fn player_attack_cooldown(
        ref self: CombatNodePath, attacks: IAttackDispatcher, attack_id: felt252, round: u32,
    ) -> felt252 {
        let cooldown = attacks.cooldown(attack_id);
        if cooldown.is_zero() {
            return attack_id;
        }
        let last_used = self.attack_last_used.read(attack_id);
        if last_used.is_zero() || ((cooldown.into() + last_used) < round) {
            self.attack_last_used.write(attack_id, round);
            return attack_id;
        }
        0
    }

    fn combat_n(self: AttemptNodePath) -> u32 {
        self.stage.read() + self.respawns.read()
    }
}

