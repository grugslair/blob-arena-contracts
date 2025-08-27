use ba_combat::CombatantState;
use ba_combat::combat::CombatProgress;
use ba_combat::result::AttackResult;
use starknet::ContractAddress;
use crate::components::{CombatPhase, LobbyPhase, Player};

#[derive(Drop, Serde, Introspect)]
pub struct Lobby {
    pub phase: LobbyPhase,
}

#[derive(Drop, Serde, Introspect)]
pub struct Combat {
    pub player_1: ContractAddress,
    pub p1_loadout: ContractAddress,
    pub p1_token: (ContractAddress, u256),
    pub p1_attacks: Span<felt252>,
    pub player_2: ContractAddress,
    pub p2_loadout: ContractAddress,
    pub p2_token: (ContractAddress, u256),
    pub p2_attacks: Span<felt252>,
    pub time_limit: u64,
    pub phase: CombatPhase,
    pub round: u32,
    pub last_timestamp: u64,
}

#[derive(Drop, Serde, Schema)]
pub struct LobbyCombatInitSchema {
    pub player_1: ContractAddress,
    pub player_2: ContractAddress,
    pub p1_loadout: ContractAddress,
    pub p2_loadout: ContractAddress,
    pub p1_token: (ContractAddress, u256),
    pub p1_attacks: Span<felt252>,
    pub time_limit: u64,
}


#[derive(Drop, Serde, Schema)]
pub struct LobbyCombatRespondSchema {
    pub p2_token: (ContractAddress, u256),
    pub p2_attacks: Span<felt252>,
}

#[derive(Drop, Serde, Schema)]
pub struct LobbyCombatStartSchema {
    pub round: u32,
    pub phase: CombatPhase,
}

#[derive(Drop, Serde, Introspect)]
pub struct Round {
    pub combat: felt252,
    pub round: u32,
    pub states: [CombatantState; 2],
    pub switch_order: bool,
    pub outcomes: Span<AttackResult>,
    pub progress: CombatProgress,
}

#[derive(Drop, Serde, Introspect)]
pub struct AttackLastUsed {
    pub combat: felt252,
    pub player: Player,
    pub attack: felt252,
    pub last_used: u32,
}

#[cfg(test)]
mod tests {
    use beacon_entity::get_schema_size;
    use super::*;


    #[test]
    fn table_size_test() {
        println!("LobbyTable size: {}", get_schema_size::<LobbyTable>());
        println!("CombatTable size: {}", get_schema_size::<CombatTable>());
        println!("CombatRound size: {}", get_schema_size::<RoundTable>());
    }
}
