use ba_combat::combat::{CombatProgress, Round};
use ba_combat::result::AttackOutcomes;
use ba_combat::{CombatantState, Player};
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
    pub p1_attacks: Span<felt252>,
    pub player_2: ContractAddress,
    pub p2_loadout: ContractAddress,
    pub p2_token: (ContractAddress, u256),
    pub p2_attacks: Span<felt252>,
    pub time_limit: u64,
    pub phase: CombatPhase,
    pub round: u32,
    pub last_timestamp: u64,
    pub win_via: WinVia,
}

#[derive(Drop, Serde, Schema)]
pub struct LobbyCombatInitSchema {
    pub player_1: ContractAddress,
    pub player_2: ContractAddress,
    pub p1_loadout: ContractAddress,
    pub p1_token: (ContractAddress, u256),
    pub p1_attacks: Span<felt252>,
    pub p2_loadout: ContractAddress,
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
pub struct PvpRoundTable {
    pub combat: felt252,
    pub round: u32,
    pub states: Span<CombatantState>,
    pub attacks: Span<felt252>,
    pub first: Player,
    pub outcomes: Span<AttackOutcomes>,
    pub progress: CombatProgress,
}

#[derive(Drop, Serde, Introspect)]
pub struct PvpAttackLastUsedTable {
    pub combat: felt252,
    pub player: Player,
    pub attack: felt252,
    pub last_used: u32,
}

#[derive(Drop, Serde, Schema)]
pub struct PvpFirstRoundSchema {
    pub combat: felt252,
    pub round: u32,
    pub states: Span<CombatantState>,
}

#[generate_trait]
pub impl PvpRoundTableImpl of PvpRoundTableTrait {
    fn to_pvp_round(self: Round, combat: felt252) -> PvpRoundTable {
        PvpRoundTable {
            combat,
            round: self.round,
            states: self.states.span(),
            attacks: self.attacks.span(),
            first: self.first,
            outcomes: self.outcomes.span(),
            progress: self.progress,
        }
    }
}


#[cfg(test)]
mod tests {
    use beacon_entity::get_schema_size;
    use super::*;


    #[test]
    fn table_size_test() {
        println!("LobbyTable size: {}", get_schema_size::<Lobby>());
        println!("CombatTable size: {}", get_schema_size::<PvpCombatTable>());
        println!("CombatRound size: {}", get_schema_size::<PvpRoundTable>());
    }
}
