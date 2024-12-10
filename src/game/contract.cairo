use starknet::ContractAddress;

use blob_arena::game::components::Combatants;
#[starknet::interface]
trait IGame<TContractState> {
    fn create(
        ref self: TContractState,
        player_a: ContractAddress,
        collection_address_a: ContractAddress,
        token_id_a: u256,
        attacks_a: Span<(felt252, felt252)>,
        player_b: ContractAddress,
        collection_address_b: ContractAddress,
        token_id_b: u256,
        attacks_b: Span<(felt252, felt252)>,
    ) -> Combatants;
    fn commit(ref self: TContractState, combatant_id: felt252, hash: felt252);
    fn reveal(ref self: TContractState, combatant_id: felt252, attack: felt252, salt: felt252);
    fn run(ref self: TContractState, combat_id: felt252);
}


#[dojo::contract]
mod game_act {
    use dojo::{world::WorldStorage, model::ModelStorage, event::EventStorage};
    use starknet::{ContractAddress, get_caller_address};
    use blob_arena::{world::default_namespace, game::{systems::GameTrait, components::Combatants},};
    use super::IGame;

    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn get_storage(self: @ContractState) -> WorldStorage {
            self.world(default_namespace())
        }
    }

    #[abi(embed_v0)]
    impl IGameImpl of IGame<ContractState> {
        fn create(
            ref self: ContractState,
            player_a: ContractAddress,
            collection_address_a: ContractAddress,
            token_id_a: u256,
            attacks_a: Span<(felt252, felt252)>,
            player_b: ContractAddress,
            collection_address_b: ContractAddress,
            token_id_b: u256,
            attacks_b: Span<(felt252, felt252)>,
        ) -> Combatants {
            let mut world = self.get_storage();
            world
                .create_game(
                    get_caller_address(),
                    player_a,
                    collection_address_a,
                    token_id_a,
                    attacks_a,
                    player_b,
                    collection_address_b,
                    token_id_b,
                    attacks_b,
                )
        }

        fn commit(ref self: ContractState, combatant_id: felt252, hash: felt252) {
            let mut world = self.get_storage();
            let mut combat = world
                .get_owners_combat_state_from_combatant_id(combatant_id, get_caller_address());
            world.commit_attack(ref combat, combatant_id, hash);
        }

        fn reveal(ref self: ContractState, combatant_id: felt252, attack: felt252, salt: felt252) {
            let mut world = self.get_storage();
            let mut combat = world
                .get_owners_combat_state_from_combatant_id(combatant_id, get_caller_address());
            world.reveal_attack(ref combat, combatant_id, attack, salt);
        }

        fn run(ref self: ContractState, combat_id: felt252) {
            let mut world = self.get_storage();
            let mut combat = world.get_owners_combat_state(combat_id, get_caller_address());
            world.run_round(ref combat);
        }
    }
}
