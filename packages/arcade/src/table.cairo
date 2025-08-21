use ba_combat::CombatantState;
use ba_combat::combat::Round;
use ba_combat::result::AttackResult;
use ba_loadout::ability::Abilities;
use starknet::ContractAddress;
use crate::attempt::ArcadePhase;


#[derive(Drop, Serde, Introspect)]
pub struct ArcadeAttempt {
    pub player: ContractAddress,
    pub collection_address: ContractAddress,
    pub token_id: u256,
    pub expiry: u64,
    pub abilities: Abilities,
    pub attacks: Span<felt252>,
    pub health_regen: u32,
    pub respawns: u32,
    pub stage: u32,
    pub phase: ArcadePhase,
}

#[derive(Drop, Serde, Introspect)]
pub struct ArcadeRound {
    pub attempt: felt252,
    pub combat: u32,
    pub round: u32,
    pub states: Span<CombatantState>,
    pub switch_order: bool,
    pub outcomes: Span<AttackResult>,
    pub phase: ArcadePhase,
}

#[derive(Drop, Serde, Introspect)]
pub struct AttackLastUsed {
    pub attempt: felt252,
    pub combat: u32,
    pub attack: felt252,
    pub round: u32,
}

#[generate_trait]
pub impl AttemptRoundImpl of AttemptRoundTrait {
    fn to_round(self: Round, attempt: felt252, combat: u32) -> ArcadeRound {
        ArcadeRound {
            attempt: attempt,
            combat: combat,
            round: self.round,
            states: self.states.span(),
            switch_order: self.switch_order,
            outcomes: self.outcomes.span(),
            phase: self.progress.into(),
        }
    }
}

#[cfg(test)]
mod tests {
    use beacon_entity::get_schema_size;
    use super::{ArcadeAttempt, ArcadeRound};


    #[test]
    fn table_size_test() {
        println!("ArcadeRound size: {}", get_schema_size::<ArcadeRound>());
        println!("ArcadeAttempt size: {}", get_schema_size::<ArcadeAttempt>());
    }
}
