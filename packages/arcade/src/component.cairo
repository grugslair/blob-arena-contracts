use ba_combat::combat::{CombatProgress, run_round};
use ba_combat::combatant::CombatantState;
use ba_loadout::ability::Abilities;
use ba_loadout::attack::{IAttackDispatcher, IAttackDispatcherTrait};
use ba_utils::felt252_to_u128;
use beacon_library::set_entity;
use core::num::traits::Zero;
use core::poseidon::poseidon_hash_span;
use starknet::storage::{
    Map, Mutable, MutableVecTrait, StorageMapReadAccess, StorageMapWriteAccess, StoragePath,
    StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Vec,
};
use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
use crate::table::{ArcadeRound, AttackLastUsed, AttemptRoundTrait};

pub type CombatNodePath = StoragePath<Mutable<CombatNode>>;
pub type AttemptNodePath = StoragePath<Mutable<AttemptNode>>;


#[derive(Drop, Serde, starknet::Store)]
pub struct Opponent {
    pub abilities: Abilities,
    pub attacks: [felt252; 4],
}

#[derive(Drop, Copy, Introspect, PartialEq, Serde, starknet::Store, Default)]
pub enum ArcadePhase {
    #[default]
    None,
    Active,
    PlayerWon,
    PlayerLost,
}

impl CombatProgressIntoArcadePhase of Into<CombatProgress, ArcadePhase> {
    fn into(self: CombatProgress) -> ArcadePhase {
        match self {
            CombatProgress::Active => ArcadePhase::Active,
            CombatProgress::Ended(player) => match player {
                true => ArcadePhase::PlayerWon,
                false => ArcadePhase::PlayerLost,
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
    pub phase: ArcadePhase,
    pub stage: u32,
    pub respawns: u32,
}

#[starknet::storage_node]
pub struct AttemptNode {
    pub player: ContractAddress,
    pub abilities: Abilities,
    pub token_hash: felt252,
    pub health_regen: u32,
    pub attacks_available: Map<felt252, bool>,
    pub combats: Map<u32, CombatNode>,
    pub expiry: u64,
    pub phase: ArcadePhase,
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
    pub phase: ArcadePhase,
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
        assert(self.phase.read() == ArcadePhase::Active, 'Attempt is not active');
    }
    fn new_attempt(
        ref self: AttemptNodePath,
        player: ContractAddress,
        abilities: Abilities,
        attacks: Array<felt252>,
        token_hash: felt252,
        health_regen: u32,
        expiry: u64,
    ) {
        self.player.write(player);
        self.expiry.write(expiry);
        self.abilities.write(abilities);
        self.token_hash.write(token_hash);
        self.health_regen.write(health_regen);
        for attack in attacks {
            self.attacks_available.write(attack, true);
        }
        self.phase.write(ArcadePhase::Active);
    }

    fn create_combat(
        ref self: StoragePath<Mutable<CombatNode>>,
        player_state: CombatantState,
        opponent_state: CombatantState,
        opponent_attacks: Span<felt252>,
    ) {
        self.player_state.write(player_state);
        self.opponent_state.write(opponent_state);
        self.phase.write(ArcadePhase::Active);
        self.round.write(1);
        for attack in opponent_attacks {
            if attack.is_non_zero() {
                self.opponent_attacks.push((*attack, 0));
            }
        }
    }

    fn get_opponent_attack(
        ref self: CombatNodePath, attacks: IAttackDispatcher, round: u32, randomness: felt252,
    ) -> felt252 {
        let (mut n, n_attacks) = (0, self.opponent_attacks.len());
        let sn = (felt252_to_u128(randomness) % n_attacks.into()).try_into().unwrap();
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

    fn attack<const LAST_USED_ATTACK_TABLE: felt252, const ROUND_TABLE_HASH: felt252>(
        ref self: AttemptNodePath,
        attacks: IAttackDispatcher,
        attempt_id: felt252,
        combat_n: u32,
        attack_id: felt252,
        randomness: felt252,
    ) -> ArcadeRound {
        self.assert_caller_is_owner();
        assert(self.phase.read() == ArcadePhase::Active, 'Game is not active');

        let mut combat: CombatNodePath = self.combats.entry(combat_n);

        let round = combat.round.read();
        let opponent_attack = combat.get_opponent_attack(attacks, round, randomness);
        let player_attack = match self.attacks_available.read(attack_id) {
            false => 0x0,
            true => combat.player_attack_cooldown(attacks, attack_id, round),
        };
        let result = run_round(
            combat.player_state.read(),
            combat.opponent_state.read(),
            attacks,
            player_attack,
            opponent_attack,
            round,
            randomness,
        )
            .to_round(attempt_id, combat_n);
        combat.player_state.write(*result.states.at(0));
        combat.opponent_state.write(*result.states.at(1));
        if result.phase == ArcadePhase::Active {
            combat.round.write(round + 1);
        } else {
            combat.phase.write(result.phase);
        }

        set_entity(
            ROUND_TABLE_HASH,
            poseidon_hash_span([attempt_id, combat_n.into(), round.into()].span()),
            @result,
        );
        if player_attack.is_non_zero() {
            set_entity(
                LAST_USED_ATTACK_TABLE,
                poseidon_hash_span([attempt_id, attack_id].span()),
                @AttackLastUsed { attack: attack_id, attempt: attempt_id, combat: combat_n, round },
            );
        }

        result
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
