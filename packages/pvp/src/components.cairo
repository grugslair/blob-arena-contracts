use ba_combat::{Combat, CombatTrait, CombatantState, Player, RoundResult};
use ba_loadout::Attributes;
use ba_loadout::attack::IAttackDispatcher;
use ba_utils::{Randomness, RandomnessTrait};
use core::panic_with_felt252;
use sai_core_utils::poseidon_hash_two;
use starknet::storage::{Map, Mutable, StoragePath, StoragePointerReadAccess};
use starknet::{ClassHash, ContractAddress, get_caller_address};

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
    pub attributes_1: Attributes,
    pub combatant_2: (Attributes, [felt252; 4]),
}


#[starknet::storage_node]
pub struct PvpNode {
    pub time_limit: u64,
    pub player_1: ContractAddress,
    pub player_2: ContractAddress,
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

    fn combat(
        self: @PvpNodePath,
        combat_id: felt252,
        attack_1: felt252,
        attack_2: felt252,
        randomness: Randomness,
        attack_dispatcher: IAttackDispatcher,
    ) -> Combat {
        let [state_1, state_2] = self.player_states.read();
        CombatTrait::new(
            combat_id,
            self.round.read(),
            state_1,
            state_2,
            attack_1,
            attack_2,
            randomness,
            attack_dispatcher,
        )
    }

    fn run_round(
        ref self: PvpNodePath,
        combat_class_hash: ClassHash,
        combat_id: felt252,
        attack_dispatcher: IAttackDispatcher,
        phase: CombatPhase,
        attack: felt252,
        salt: felt252,
    ) -> RoundResult {
        let [[attack_1, salt_1], [attack_2, salt_2]] = match phase {
            CombatPhase::Player1Revealed => [self.reveal.read(), [attack, salt]],
            CombatPhase::Player2Revealed => [[attack, salt], self.reveal.read()],
            _ => panic_with_felt252('Invalid combat phase'),
        };
        let randomness = RandomnessTrait::new(poseidon_hash_two(salt_1, salt_2));

        let mut combat = self.combat(combat_id, attack_1, attack_2, randomness, attack_dispatcher);
        combat.run_round(true, true);
        combat.to_round()
    }
}

