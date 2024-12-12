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
        let collection_dispatcher = get_collection_dispatcher(collection_address);
        self.set_combatant_token(combatant_id, collection_address, token_id);
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
        let owner = collection_dispatcher.get_owner(token_id);
        assert(player == owner, 'Not Owner');
        self.set_combatant_info(combatant_id, combat_id, player);
        self.set_combatant_token(combatant_id, collection_address, token_id);
        self.create_combatant_state(combatant_id, collection_dispatcher.get_stats(token_id));
        self.setup_available_attacks(collection_dispatcher, token_id, combatant_id, attacks);
    }

    fn assert_caller_player(self: @WorldStorage, combatant_id: felt252) {
        assert(self.get_player(combatant_id) == get_caller_address(), 'Caller not player');
    }

    fn has_attack(
        self: @WorldStorage,
        collection: ICollectionDispatcher,
        token_id: u256,
        item_id: felt252,
        attack_id: felt252
    ) -> bool {
        collection.has_attack(token_id, item_id, attack_id)
    }

    fn setup_available_attacks(
        ref self: WorldStorage,
        collection: ICollectionDispatcher,
        token_id: u256,
        combatant_id: felt252,
        mut attacks: Array<(felt252, felt252)>
    ) {
        loop {
            match attacks.pop_front() {
                Option::Some((
                    item_id, attack_id
                )) => {
                    if self.has_attack(collection, token_id, item_id, attack_id) {
                        self.set_attack_available(combatant_id, attack_id);
                    }
                },
                Option::None => { break; }
            }
        };
    }
}
