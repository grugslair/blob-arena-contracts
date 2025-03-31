use starknet::{ContractAddress, get_caller_address};
use dojo::{world::WorldStorage, model::{ModelStorage, Model}};

use crate::attacks::{AttackStorage, AttackTrait};
use crate::combatants::{
    CombatantInfo, CombatantInfoTrait, CombatantStateTrait, CombatantToken,
    components::{get_combatant_id, make_combatant_state}, CombatantStorage, CombatantSetup,
};
use crate::combat::{CombatState, CombatTrait};
use crate::stats::{UStats, StatsTrait};
use crate::collections::{collection_dispatcher, ICollectionDispatcherTrait, ICollectionDispatcher};
use crate::experience::ExperienceTrait;

#[generate_trait]
impl CombatantImpl of CombatantTrait {
    fn create_combatant(
        ref self: WorldStorage,
        combatant_id: felt252,
        player: ContractAddress,
        combat_id: felt252,
        collection_address: ContractAddress,
        token_id: u256,
        attacks: Array<(felt252, felt252)>,
    ) {
        self.set_combatant_info(combatant_id, combat_id, player);
        self.set_combatant_token(combatant_id, collection_address, token_id);
        self.setup_combatant_state_and_attacks(combatant_id, collection_address, token_id, attacks);
    }

    fn get_token_stats_and_attacks<T, +Into<T, ICollectionDispatcher>>(
        self: T, token_id: u256, attacks: Array<(felt252, felt252)>,
    ) -> (UStats, Array<felt252>) {
        let dispatcher: ICollectionDispatcher = self.into();
        (dispatcher.get_stats(token_id), dispatcher.get_attack_slots(token_id, attacks))
    }

    fn get_total_stats_and_attacks(
        ref self: WorldStorage,
        collection: ContractAddress,
        token_id: u256,
        player: ContractAddress,
        attacks: Array<(felt252, felt252)>,
    ) -> (UStats, Array<felt252>) {
        let (stats, attacks) = collection.get_token_stats_and_attacks(token_id, attacks);
        let experience = self.get_experience(collection, token_id, player);
        let bonus_stats = self.get_experience_stats(collection, token_id, player);

        ((stats + bonus_stats).limit_stats(), self.check_attacks_requirements(experience, attacks))
    }

    fn setup_combatant_state_and_attacks(
        ref self: WorldStorage,
        combatant_id: felt252,
        collection_address: ContractAddress,
        token_id: u256,
        attacks: Array<(felt252, felt252)>,
    ) {
        let collection_dispatcher = collection_dispatcher(collection_address);
        let (stats, attack_ids) = collection_dispatcher
            .get_token_stats_and_attacks(token_id, attacks);
        self.set_combatant_stats_and_attacks(combatant_id, stats, attack_ids.span());
    }

    fn set_combatant_stats_and_attacks(
        ref self: WorldStorage, combatant_id: felt252, stats: UStats, attacks: Span<felt252>,
    ) {
        self.create_combatant_state(combatant_id, stats);
        self.set_combatant_attacks_available(combatant_id, attacks);
    }

    fn set_combatant_stats_health_and_attacks(
        ref self: WorldStorage,
        combatant_id: felt252,
        stats: UStats,
        health: u8,
        attacks: Span<felt252>,
    ) {
        self.set_combatant_attacks_available(combatant_id, attacks);
        self.set_combatant_state(combatant_id, health, 0, stats);
    }

    fn create_player_combatant(
        ref self: WorldStorage,
        combatant_id: felt252,
        player: ContractAddress,
        combat_id: felt252,
        collection_address: ContractAddress,
        token_id: u256,
        attacks: Array<(felt252, felt252)>,
    ) -> Array<felt252> {
        let collection_dispatcher = collection_dispatcher(collection_address);
        let owner = collection_dispatcher.owner_of(token_id);
        assert(player == owner, 'Not Owner');
        self.set_combatant_info(combatant_id, combat_id, player);
        self.set_combatant_token(combatant_id, collection_address, token_id);
        self.create_combatant_state(combatant_id, collection_dispatcher.get_stats(token_id));
        self.setup_available_attacks(collection_dispatcher, token_id, combatant_id, attacks)
    }

    fn assert_caller_player(self: @WorldStorage, combatant_id: felt252) {
        assert(self.get_player(combatant_id) == get_caller_address(), 'Caller not player');
    }

    fn setup_available_attacks(
        ref self: WorldStorage,
        collection: ICollectionDispatcher,
        token_id: u256,
        combatant_id: felt252,
        attacks: Array<(felt252, felt252)>,
    ) -> Array<felt252> {
        let attack_ids = collection.get_attack_slots(token_id, attacks);
        self.set_combatant_attacks_available(combatant_id, attack_ids.span());
        attack_ids
    }

    fn reset_combatant(
        ref self: WorldStorage,
        combatant_id: felt252,
        health: u8,
        stats: UStats,
        attacks: Array<felt252>,
    ) {
        self.reset_attacks_last_used(combatant_id, attacks);
        self.set_combatant_state(combatant_id, health, 0, stats);
    }
}
