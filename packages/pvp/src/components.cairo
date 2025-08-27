use ba_combat::CombatantState;
use ba_combat::combat::{CombatProgress, run_round};
use ba_loadout::ability::Abilities;
use ba_loadout::attack::{IAttackDispatcher, IAttackDispatcherTrait};
use core::num::traits::Zero;
use core::panic_with_felt252;
use sai_core_utils::poseidon_hash_two;
use starknet::storage::{
    Map, Mutable, PendingStoragePath, StorageMapReadAccess, StorageMapWriteAccess, StoragePath,
    StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
};
use starknet::{ContractAddress, get_block_timestamp, get_caller_address};

type PvpNodePath = StoragePath<Mutable<PvpNode>>;

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
    Reveal,
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
    pub attacks_1: Map<u32, felt252>,
    pub attacks_2: Map<u32, felt252>,
    pub commit_1: felt252,
    pub commit_2: felt252,
    pub reveal: [felt252; 2],
    pub player_states: [CombatantState; 2],
    pub attack_used_1: Map<felt252, u32>,
    pub attack_used_2: Map<felt252, u32>,
    pub phase: CombatPhase,
    pub round: u32,
    pub timestamp: u64,
}


#[derive(Copy, Drop, Serde, PartialEq, Default, Introspect)]
pub enum Player {
    #[default]
    Player1,
    Player2,
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
    ) {
        let [state_1, state_2] = self.player_states.read();
        let ([attack_1, salt_1], [attack_2, salt_2]) = match phase {
            CombatPhase::Player1Revealed => (self.reveal.read(), [attack, salt]),
            CombatPhase::Player2Revealed => ([attack, salt], self.reveal.read()),
            _ => panic_with_felt252('Invalid combat phase'),
        };
        let randomness = poseidon_hash_two(salt_1, salt_2);
        let round = self.round.read();
        let cooldowns = attack_dispatcher.cooldowns(array![attack_1, attack_2]);
        let attack_1 = self.attack_used_1.run_cooldown(attack_1, *cooldowns.at(0), round);
        let attack_2 = self.attack_used_2.run_cooldown(attack_2, *cooldowns.at(1), round);
        let result = run_round(
            state_1, state_2, attack_dispatcher, attack_1, attack_2, round, randomness,
        );
        self.player_states.write(result.states);
        match result.progress {
            CombatProgress::Active => self.round.write(round + 1),
            CombatProgress::Ended(p1_won) => match p1_won {
                true => self.phase.write(CombatPhase::WinnerPlayer1),
                false => self.phase.write(CombatPhase::WinnerPlayer2),
            },
        };
    }

    fn run_cooldown(
        self: PendingStoragePath<Mutable<Map<felt252, u32>>>,
        attack_id: felt252,
        cooldown: u8,
        round: u32,
    ) -> felt252 {
        if cooldown.is_zero() {
            return attack_id;
        }
        let last_used = self.read(attack_id);
        if last_used.is_zero() || ((cooldown.into() + last_used) < round) {
            self.write(attack_id, round);
            return attack_id;
        }
        0
    }
}

