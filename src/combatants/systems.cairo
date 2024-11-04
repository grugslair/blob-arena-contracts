use starknet::ContractAddress;
use dojo::{world::WorldStorage, model::ModelStorage};
use blob_arena::{
    attacks::AvailableAttackTrait,
    combatants::{
        CombatantInfo, CombatantState, CombatantInfoTrait, CombatantStateTrait,
        components::{get_combatant_id, make_combatant_state}
    },
    stats::UStats,
    collections::{get_collection_dispatcher, ICollectionDispatcherTrait, ICollectionDispatcher}
};

#[generate_trait]
impl CombatantImpl of CombatantTrait {
    fn create_combatant(
        ref self: WorldStorage,
        collection_address: ContractAddress,
        token_id: u256,
        combat_id: felt252,
        player: ContractAddress,
        attacks: Span<(felt252, felt252)>
    ) -> CombatantInfo {
        let collection_dispatcher = get_collection_dispatcher(collection_address);
        let combatant_id = get_combatant_id(collection_address, token_id, combat_id);

        self.setup_available_attacks(collection_dispatcher, token_id, combatant_id, attacks);
        let info = CombatantInfo {
            id: combatant_id, combat_id, player, collection_address, token_id,
        };
        let stats: UStats = collection_dispatcher.get_stats(token_id);
        self.write_model(@make_combatant_state(combatant_id, @stats));
        self.write_model(@info);
        info
    }
    fn get_combatant_info(self: @WorldStorage, id: felt252) -> CombatantInfo {
        self.read_model(id)
    }
    fn create_player_combatant(
        ref self: WorldStorage,
        collection_address: ContractAddress,
        token_id: u256,
        challenge_id: felt252,
        player: ContractAddress,
        attacks: Span<(felt252, felt252)>
    ) -> CombatantInfo {
        let collection = get_collection_dispatcher(collection_address);
        let owner = collection.get_owner(token_id);
        assert(player == owner, 'Not Owner');
        self.create_combatant(collection_address, token_id, challenge_id, player, attacks)
    }
    fn get_combatant_info_in_combat(self: @WorldStorage, id: felt252) -> CombatantInfo {
        let combatant = self.get_combatant_info(id);
        assert(combatant.combat_id.is_non_zero(), 'Not valid combatant');
        combatant
    }
    fn get_player_combatant_info(self: @WorldStorage, id: felt252) -> CombatantInfo {
        let combatant = self.get_combatant_info(id);
        combatant.assert_player();
        combatant
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
        mut attacks: Span<(felt252, felt252)>
    ) {
        loop {
            match attacks.pop_front() {
                Option::Some((
                    item_id, attack_id
                )) => {
                    if self.has_attack(collection, token_id, *item_id, *attack_id) {
                        self.set_attack_available(combatant_id, *attack_id);
                    }
                },
                Option::None => { break; }
            }
        };
    }
}
