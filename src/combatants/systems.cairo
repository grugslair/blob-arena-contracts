use starknet::{ContractAddress, get_caller_address};
use dojo::{world::WorldStorage, model::{ModelStorage, Model}};
use blob_arena::{
    attacks::AttackStorage,
    combatants::{
        CombatantInfo, CombatantInfoTrait, CombatantStateTrait, CombatantToken,
        components::{get_combatant_id, make_combatant_state}, CombatantStorage
    },
    combat::{CombatState, CombatTrait}, stats::UStats,
    collections::{get_collection_dispatcher, ICollectionDispatcherTrait, ICollectionDispatcher}
};

#[generate_trait]
impl CombatantImpl of CombatantTrait {
    fn create_combatant(
        ref self: WorldStorage,
        combatant_id: felt252,
        player: ContractAddress,
        combat_id: felt252,
        collection_address: ContractAddress,
        token_id: u256,
        attacks: Array<(felt252, felt252)>
    ) {
        self.set_combatant_info(combatant_id, combat_id, player);
        self.set_combatant_token(combatant_id, collection_address, token_id);
        self.setup_combatant_state_and_attacks(combatant_id, collection_address, token_id, attacks);
    }

    fn setup_combatant_state_and_attacks(
        ref self: WorldStorage,
        combatant_id: felt252,
        collection_address: ContractAddress,
        token_id: u256,
        attacks: Array<(felt252, felt252)>,
    ) {
        let collection_dispatcher = get_collection_dispatcher(collection_address);
        self.create_combatant_state(combatant_id, collection_dispatcher.get_stats(token_id));
        self.setup_available_attacks(collection_dispatcher, token_id, combatant_id, attacks);
    }

    fn create_player_combatant(
        ref self: WorldStorage,
        combatant_id: felt252,
        player: ContractAddress,
        combat_id: felt252,
        collection_address: ContractAddress,
        token_id: u256,
        attacks: Array<(felt252, felt252)>
    ) {
        let collection_dispatcher = get_collection_dispatcher(collection_address);
        let owner = collection_dispatcher.owner_of(token_id);
        assert(player == owner, 'Not Owner');
        self.set_combatant_info(combatant_id, combat_id, player);
        self.set_combatant_token(combatant_id, collection_address, token_id);
        self.create_combatant_state(combatant_id, collection_dispatcher.get_stats(token_id));
        self.setup_available_attacks(collection_dispatcher, token_id, combatant_id, attacks);
    }

    fn assert_caller_player(self: @WorldStorage, combatant_id: felt252) {
        assert(self.get_player(combatant_id) == get_caller_address(), 'Caller not player');
    }

    fn setup_available_attacks(
        ref self: WorldStorage,
        collection: ICollectionDispatcher,
        token_id: u256,
        combatant_id: felt252,
        mut attacks: Array<(felt252, felt252)>
    ) {
        self
            .set_combatant_attacks_available(
                combatant_id, collection.get_attack_slots(token_id, attacks)
            );
    }
}
