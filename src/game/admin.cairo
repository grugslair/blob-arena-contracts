use starknet::ContractAddress;


#[starknet::interface]
trait IGameAdmin<TContractState> {
    fn create(
        ref self: TContractState,
        owner: ContractAddress,
        initiator: ContractAddress,
        time_limit: u64,
        player_a: ContractAddress,
        collection_address_a: ContractAddress,
        token_id_a: u256,
        attacks_a: Array<(felt252, felt252)>,
        player_b: ContractAddress,
        collection_address_b: ContractAddress,
        token_id_b: u256,
        attacks_b: Array<(felt252, felt252)>
    ) -> felt252;
}

#[dojo::contract]
mod game_admin {
    use starknet::ContractAddress;
    use blob_arena::{
        world::{default_namespace, uuid, WorldTrait}, game::GameStorage, combatants::CombatantTrait,
        combat::CombatStorage
    };

    use super::IGameAdmin;

    #[abi(embed_v0)]
    impl IGameAdminImpl of IGameAdmin<ContractState> {
        fn create(
            ref self: ContractState,
            owner: ContractAddress,
            initiator: ContractAddress,
            time_limit: u64,
            player_a: ContractAddress,
            collection_address_a: ContractAddress,
            token_id_a: u256,
            attacks_a: Array<(felt252, felt252)>,
            player_b: ContractAddress,
            collection_address_b: ContractAddress,
            token_id_b: u256,
            attacks_b: Array<(felt252, felt252)>
        ) -> felt252 {
            let mut world = self.world(default_namespace());
            world.assert_caller_is_admin(selector!("blob_arena-game_admin"));
            let id = uuid();
            let player_a_id = uuid();
            let player_b_id = uuid();

            world
                .create_player_combatant(
                    player_a_id, player_a, id, collection_address_a, token_id_a, attacks_a
                );
            world
                .create_player_combatant(
                    player_b_id, player_b, id, collection_address_b, token_id_b, attacks_b
                );

            world.set_game_info(id, owner, time_limit, player_a_id, player_b_id);
            world.set_initiator(id, initiator);
            world.new_combat_state(id);
            id
        }
    }
}
