use ba_combat::combatant::CombatantState;
use ba_loadout::ability::Abilities;
use starknet::ContractAddress;
use starknet::storage::{Map, Mutable, StoragePath, Vec};

type RoundNodePath = StoragePath<Mutable<RoundNode>>;

#[derive(Drop, Copy, Introspect, PartialEq, Serde, starknet::Store, Default)]
pub enum ArcadePhase {
    #[default]
    None,
    Active,
    PlayerWon,
    PlayerLost,
}


// #[starknet::component]
// mod combat_component {
//     #[storage]
//     struct Storage {
//         combat: Map<u128, Combat>,
//     }
// }

#[starknet::storage_node]
pub struct AttemptNode {
    pub player: ContractAddress,
    pub collection_address: ContractAddress,
    pub token_id: u256,
    pub abilities: Abilities,
    pub attacks_available: Map<felt252, bool>,
    pub stages: Vec<RoundNode>,
    pub expiry: u64,
    pub phase: ArcadePhase,
    pub respawns: u32,
    pub stage: u32,
}

#[starknet::storage_node]
pub struct RoundNode {
    pub player_state: CombatantState,
    pub opponent_state: CombatantState,
    pub player_last_used: Map<felt252, u32>,
    pub opponent_attacks: Vec<(felt252, u32)>,
    pub phase: ArcadePhase,
}


#[generate_trait]
impl AttemptNodeImpl of AttemptNodeTrait {
    fn get_oppoenet_attack(ref self: RoundNodePath, round_index: u32) -> Vec<(felt252, u32)> {
        assert(round_index < self.rounds.len(), 'Invalid round index');
        self.rounds[round_index].opponent_attacks.read()
    }
}

