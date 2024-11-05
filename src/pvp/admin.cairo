// For testing only
use starknet::{ContractAddress};
use dojo::world::{WorldStorage, ModelStorage};


#[dojo::interface]
trait IPvPAdminActions {
    fn create_challenge(
        ref self: ContractState,
        collection_address_a: ContractAddress,
        collection_address_b: ContractAddress,
        player_a: ContractAddress,
        player_b: ContractAddress,
        token_a_id: u256,
        token_b_id: u256,
        attacks_a: Span<(felt252, felt252)>,
        attacks_b: Span<(felt252, felt252)>,
    ) -> felt252;
    fn set_winner(ref self: ContractState, combatant_id: felt252);
}

#[dojo::contract]
mod pvp_admin_actions {
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use blob_arena::{
        collections::interface::get_collection_dispatcher,
        components::{
            combatant::CombatantTrait, combat::{CombatStateTrait, CombatStatesTrait},
            pvp_combat::PvPCombatTrait, pvp_challenge::PvPChallengeScoreTrait, utils::ABTOtherTrait
        },
        utils::uuid, world::{Contract, WorldTrait}, Permissions, default_namespace
    };
    use super::IPvPAdminActions;
}

