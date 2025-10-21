use ba_combat::Player;
use starknet::ContractAddress;
use crate::components::{CombatPhase, LobbyPhase};

#[derive(Copy, Drop, Serde, PartialEq, Introspect, Default)]
pub enum WinVia {
    #[default]
    None,
    Combat,
    Forfeit,
    IncorrectReveal,
    TimedOut,
}

#[derive(Drop, Serde, Introspect)]
pub struct Lobby {
    pub phase: LobbyPhase,
}

#[derive(Drop, Serde, Introspect)]
pub struct PvpCombatTable {
    pub lobby: LobbyPhase,
    pub player_1: ContractAddress,
    pub p1_loadout: ContractAddress,
    pub p1_token: (ContractAddress, u256),
    pub p1_actions: Span<felt252>,
    pub p1_orb: felt252,
    pub player_2: ContractAddress,
    pub p2_loadout: ContractAddress,
    pub p2_token: (ContractAddress, u256),
    pub p2_actions: Span<felt252>,
    pub p2_orb: felt252,
    pub time_limit: u64,
    pub phase: CombatPhase,
    pub round: u32,
    pub last_timestamp: u64,
    pub win_via: WinVia,
}

#[derive(Drop, Serde, Schema)]
pub struct LobbyCombatInitSchema {
    pub lobby: LobbyPhase,
    pub player_1: ContractAddress,
    pub player_2: ContractAddress,
    pub p1_loadout: ContractAddress,
    pub p1_token: (ContractAddress, u256),
    pub p1_actions: Span<felt252>,
    pub p1_orb: felt252,
    pub p2_loadout: ContractAddress,
    pub time_limit: u64,
}


#[derive(Drop, Serde, Schema)]
pub struct LobbyCombatRespondSchema {
    pub lobby: LobbyPhase,
    pub p2_token: (ContractAddress, u256),
    pub p2_actions: Span<felt252>,
    pub p2_orb: felt252,
}

#[derive(Drop, Serde, Schema)]
pub struct LobbyCombatStartSchema {
    pub round: u32,
    pub phase: CombatPhase,
}

#[derive(Drop, Serde, Introspect)]
pub struct PvpActionLastUsedTable {
    pub combat: felt252,
    pub player: Player,
    pub action: felt252,
    pub last_used: u32,
}

#[cfg(test)]
mod tests {
    use beacon_entity::get_schema_size;
    use super::*;


    #[test]
    fn table_size_test() {
        println!("LobbyTable size: {}", get_schema_size::<Lobby>());
        println!("CombatTable size: {}", get_schema_size::<PvpCombatTable>());
    }
}
