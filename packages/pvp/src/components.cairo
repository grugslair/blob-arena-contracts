use ba_combat::combat::{Round, run_round};
use ba_combat::{CombatantState, Player};
use ba_loadout::ability::Abilities;
use ba_loadout::attack::{IAttackDispatcher, IAttackDispatcherTrait};
use core::num::traits::Zero;
use core::panic_with_felt252;
use sai_core_utils::poseidon_hash_two;
use starknet::storage::{
    Map, Mutable, StorageMapReadAccess, StorageMapWriteAccess, StoragePath,
    StoragePointerReadAccess,
};
use starknet::{ContractAddress, get_caller_address};

pub type PvpNodePath = StoragePath<Mutable<PvpNode>>;

#[derive(Copy, Drop, Serde, PartialEq, Introspect, Default, starknet::Store)]
pub enum LobbyPhase {
    #[default]
    InActive,
    Invited,
    Responded,
    Accepted,
}

#[derive(Copy, Drop, Serde, PartialEq, Introspect, Default, starknet::Store)]
pub enum CombatPhase {
    #[default]
    None,
    Created,
    Commit,
    Player1Committed,
    Player2Committed,
    Player1Revealed,
    Player2Revealed,
    WinnerPlayer1,
    WinnerPlayer2,
}


#[starknet::storage_node]
pub struct LobbyNode {
    pub phase: LobbyPhase,
    pub loadout_address: ContractAddress,
    pub abilities_1: Abilities,
    pub combatant_2: (Abilities, [felt252; 4]),
}


#[starknet::storage_node]
pub struct PvpNode {
    pub time_limit: u64,
    pub player_1: ContractAddress,
    pub player_2: ContractAddress,
    pub p1_attack_available: Map<felt252, bool>,
    pub p2_attack_available: Map<felt252, bool>,
    pub commit: felt252,
    pub reveal: [felt252; 2],
    pub player_states: [CombatantState; 2],
    pub p1_attack_used: Map<felt252, u32>,
    pub p2_attack_used: Map<felt252, u32>,
    pub phase: CombatPhase,
    pub round: u32,
    pub timestamp: u64,
}

#[generate_trait]
pub impl PvpNodeImpl of PvpNodeTrait {
    fn assert_caller_is_player(self: @PvpNodePath, player: Player) -> ContractAddress {
        let caller = get_caller_address();
        assert(
            caller == match player {
                Player::Player1 => self.player_1.read(),
                Player::Player2 => self.player_2.read(),
            },
            'Caller not player',
        );
        caller
    }

    fn run_round(
        ref self: PvpNodePath,
        attack_dispatcher: IAttackDispatcher,
        phase: CombatPhase,
        attack: felt252,
        salt: felt252,
    ) -> Round {
        let [state_1, state_2] = self.player_states.read();
        let [[attack_1, salt_1], [attack_2, salt_2]] = match phase {
            CombatPhase::Player1Revealed => [self.reveal.read(), [attack, salt]],
            CombatPhase::Player2Revealed => [[attack, salt], self.reveal.read()],
            _ => panic_with_felt252('Invalid combat phase'),
        };
        let randomness = poseidon_hash_two(salt_1, salt_2);

        let round = self.round.read();
        let attack_1 = self.run_cooldown(attack_dispatcher, Player::Player1, attack_1, round);
        let attack_2 = self.run_cooldown(attack_dispatcher, Player::Player2, attack_2, round);

        run_round(state_1, state_2, attack_dispatcher, attack_1, attack_2, round, randomness)
    }

    fn run_cooldown(
        self: PvpNodePath,
        dispatcher: IAttackDispatcher,
        player: Player,
        attack_id: felt252,
        round: u32,
    ) -> felt252 {
        let (attack_available_ptr, last_used_ptr) = match player {
            Player::Player1 => (self.p1_attack_available, self.p1_attack_used),
            Player::Player2 => (self.p2_attack_available, self.p2_attack_used),
        };
        if !attack_available_ptr.read(attack_id) {
            return 0;
        }
        let cooldown = dispatcher.cooldown(attack_id);
        if cooldown.is_zero() {
            return attack_id;
        }
        let last_used = last_used_ptr.read(attack_id);
        if last_used.is_zero() || ((cooldown.into() + last_used) < round) {
            last_used_ptr.write(attack_id, round);
            return attack_id;
        }
        0
    }
}

