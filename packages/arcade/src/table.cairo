use ba_combat::combat::PlayerOrNone;
use ba_combat::{AttackResult, Combat, CombatantState, RoundEffectResult};
use ba_loadout::attributes::Attributes;
use starknet::ContractAddress;
use crate::attempt::ArcadeProgress;


#[derive(Drop, Serde, Introspect)]
pub struct ArcadeAttempt {
    pub player: ContractAddress,
    pub collection_address: ContractAddress,
    pub token_id: u256,
    pub expiry: u64,
    pub attributes: Attributes,
    pub attacks: Span<felt252>,
    pub health_regen: u8,
    pub respawns: u32,
    pub stage: u32,
    pub phase: ArcadeProgress,
}

#[derive(Drop, Serde, Introspect)]
pub struct ArcadeRoundResult {
    pub attempt: felt252,
    pub combat: u32,
    pub round: u32,
    pub player_state: CombatantState,
    pub opponent_state: CombatantState,
    pub player_attack: felt252,
    pub opponent_attack: felt252,
    pub first: PlayerOrNone,
    pub round_effect_results: Array<RoundEffectResult>,
    pub attack_results: Array<AttackResult>,
    pub progress: ArcadeProgress,
}

#[derive(Drop, Schema, Serde)]
pub struct ArcadeZeroRoundResult {
    pub attempt: felt252,
    pub combat: u32,
    pub states: [CombatantState; 2],
    pub progress: ArcadeProgress,
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
    fn to_arcade_round(self: Combat, attempt: felt252, combat: u32) -> ArcadeRoundResult {
        ArcadeRoundResult {
            attempt: attempt,
            combat: combat,
            round: self.round,
            player_state: self.state_1,
            opponent_state: self.state_2,
            player_attack: self.attack_1,
            opponent_attack: self.attack_2,
            first: self.first.into(),
            round_effect_results: self.round_effect_results,
            attack_results: self.attack_results,
            progress: self.progress.into(),
        }
    }
}

#[cfg(test)]
mod tests {
    use beacon_entity::get_schema_size;
    use super::{ArcadeAttempt, ArcadeRoundResult};


    #[test]
    fn table_size_test() {
        println!("ArcadeRound size: {}", get_schema_size::<ArcadeRoundResult>());
        println!("ArcadeAttempt size: {}", get_schema_size::<ArcadeAttempt>());
    }
}
