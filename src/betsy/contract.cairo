use starknet::ContractAddress;

#[starknet::interface]
trait IBetsyInterface<TContractState> {
    fn create(
        ref self: TContractState,
        time_limit: u64,
        initiator: ContractAddress,
        player_a: ContractAddress,
        collection_address_a: ContractAddress,
        token_id_a: u256,
        attacks_a: Span<(felt252, felt252)>,
        player_b: ContractAddress,
        collection_address_b: ContractAddress,
        token_id_b: u256,
        attacks_b: Span<(felt252, felt252)>,
    ) -> felt252;
    fn start(ref self: TContractState, game_id: felt252);
    fn commit(ref self: TContractState, combatant_id: felt252, hash: felt252);
    fn reveal(ref self: TContractState, combatant_id: felt252, attack: felt252, salt: felt252);
    fn run(ref self: TContractState, combat_id: felt252);
    fn kick_player(ref self: TContractState, combatant_id: felt252);
    fn get_winner(ref self: TContractState, combat_id: felt252) -> ContractAddress;
}

#[dojo::contract]
mod betsy {
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use dojo::{world::{WorldStorage, WorldStorageTrait}};
    use blob_arena::{
        combat::{Phase, CombatTrait, CombatState}, combatants::CombatantTrait,
        game::{contract::{IGameDispatcherTrait}, systems::GameTrait},
        betsy::{components::{game_dispatcher, set_game_contract_address}, systems::BetsyTrait,},
        world::default_namespace, commitments::Commitment,
    };
    use super::IBetsyInterface;

    fn dojo_init(ref self: ContractState, betsy_contract_address: ContractAddress) {}


    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn get_storage(self: @ContractState) -> WorldStorage {
            self.world(@"ba_timed")
        }

        fn get_combat(ref self: WorldStorage, combatant_id: felt252) -> CombatState {
            let combat = self
                .get_owners_combat_state_from_combatant_id(combatant_id, get_contract_address());
            self.assert_caller_combatant(combatant_id);
            self.set_last_timestamp(combat.id);
            combat
        }
    }

    #[abi(embed_v0)]
    impl IBestyImpl of IBetsyInterface<ContractState> {
        fn create(
            ref self: ContractState,
            time_limit: u64,
            initiator: ContractAddress,
            player_a: ContractAddress,
            collection_address_a: ContractAddress,
            token_id_a: u256,
            attacks_a: Span<(felt252, felt252)>,
            player_b: ContractAddress,
            collection_address_b: ContractAddress,
            token_id_b: u256,
            attacks_b: Span<(felt252, felt252)>,
        ) -> felt252 {
            let mut world = self.get_storage();
            let game = world
                .create_game(
                    get_contract_address(),
                    player_a,
                    collection_address_a,
                    token_id_a,
                    attacks_a,
                    player_b,
                    collection_address_b,
                    token_id_b,
                    attacks_b,
                );
            let (combatant_a, combatant_b) = game.combatant_ids;
            world.set_time_limit(game.combat_id, time_limit);
            world.set_player(combatant_a, player_a);
            world.set_player(combatant_b, player_b);
            game.combat_id
        }
        fn start(ref self: ContractState, game_id: felt252) {
            let mut world = self.get_storage();
            let combat = world.get_owners_combat_state(game_id, get_contract_address());
            assert(combat.phase == Phase::Created, 'Game not in creation phase');
            assert(world.get_initiator(game_id) == get_caller_address(), 'Not the initiator');
            world.set_combat_phase(game_id, Phase::Commit);
        }
        fn commit(ref self: ContractState, combatant_id: felt252, hash: felt252) {
            let mut world = self.get_storage();
            let mut combat = world
                .get_owners_combat_state_from_combatant_id(combatant_id, get_contract_address());
            world.assert_caller_combatant(combatant_id);

            world.commit_attack(ref combat, combatant_id, hash);
            if combat.phase == Phase::Commit {
                world.set_last_timestamp(combat.id);
            };
        }
        fn reveal(ref self: ContractState, combatant_id: felt252, attack: felt252, salt: felt252) {
            let mut world = self.get_storage();

            let mut combat = world
                .get_owners_combat_state_from_combatant_id(combatant_id, get_contract_address());
            world.assert_caller_combatant(combatant_id);
            world.set_last_timestamp(combat.id);

            world.reveal_attack(ref combat, combatant_id, attack, salt);

            if world.check_commitment_set(world.get_opponent_id(combat.id, combatant_id)) {
                world.set_last_timestamp(combat.id);
            }
        }
        fn run(ref self: ContractState, combat_id: felt252) {
            let mut world = self.get_storage();
            let mut combat = world.get_owners_combat_state(combat_id, get_contract_address());

            world.run_round(ref combat);
        }

        fn kick_player(ref self: ContractState, combatant_id: felt252) {
            let mut storage = self.get_storage();
            let combat_id = storage.get_combat_id_from_combatant_id(combatant_id);
            storage.assert_no_winner(combat_id);
            storage.assert_past_time_limit(combat_id);
            let opponent = storage.get_opponent_id(combat_id, combatant_id);
            let player = storage.get_player(opponent);

            let (player_state, opponent_state) = storage
                .get_states(combat_id, combatant_id, opponent);
            assert(opponent_state == false, 'Player has played');
            assert(player_state == true, 'Other Player has not played');

            storage.set_winner(combat_id, player);
        }

        fn get_winner(ref self: ContractState, combat_id: felt252) -> ContractAddress {
            let storage = self.get_storage();
            storage.get_winning_player(combat_id)
        }
    }
}
