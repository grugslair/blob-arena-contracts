use starknet::ContractAddress;

#[starknet::interface]
trait IGame<TContractState> {
    fn create(
        ref self: TContractState,
        initiator: ContractAddress,
        time_limit: u64,
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
    fn kick_player(ref self: TContractState, combat_id: felt252);
    fn get_winner(ref self: TContractState, combat_id: felt252) -> ContractAddress;
}

#[dojo::contract]
mod game_actions {
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use dojo::{world::{WorldStorage, WorldStorageTrait}};
    use blob_arena::{
        attacks::AttackStorage, combat::{Phase, CombatTrait, CombatState, CombatStorage},
        combatants::{CombatantTrait, CombatantStorage},
        game::{components::{GameInfoTrait}, storage::{GameStorage}, systems::GameTrait,},
        world::default_namespace, commitments::Commitment, salts::Salts,
        core::{TTupleSized2ToSpan, ArrayTryIntoTTupleSized2}
    };
    use super::IGame;

    fn dojo_init(ref self: ContractState, betsy_contract_address: ContractAddress) {}


    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn get_storage(self: @ContractState) -> WorldStorage {
            self.world(@"ba_timed")
        }
    }

    #[abi(embed_v0)]
    impl IGameImpl of IGame<ContractState> {
        fn create(
            ref self: ContractState,
            initiator: ContractAddress,
            time_limit: u64,
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
            world
                .create_game(
                    get_contract_address(),
                    initiator,
                    time_limit,
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
        fn start(ref self: ContractState, game_id: felt252) {
            let mut world = self.get_storage();
            world.assert_caller_initiator(game_id);
            world.assert_created_phase(game_id);
            world.set_combat_phase(game_id, Phase::Commit);
        }
        fn commit(ref self: ContractState, combatant_id: felt252, hash: felt252) {
            let mut world = self.get_storage();
            let combatant = world.get_callers_combatant_info(combatant_id);
            let game = world.get_owners_game(combatant.combat_id, get_contract_address());
            world.assert_commit_phase(game.combat_id);
            world.set_new_commitment(combatant_id, hash);
            let opponent_id = game.get_opponent_id(combatant_id);

            if world.check_commitment_set(opponent_id) {
                world.set_combat_phase(game.combat_id, Phase::Reveal);
            } else if game.time_limit.is_non_zero() {
                world.set_last_timestamp(game.combat_id);
            }
        }
        fn reveal(ref self: ContractState, combatant_id: felt252, attack: felt252, salt: felt252) {
            let mut world = self.get_storage();
            let combatant = world.get_callers_combatant_info(combatant_id);
            let game = world.get_owners_game(combatant.combat_id, get_contract_address());

            let opponent_id = game.get_opponent_id(combatant_id);
            if world.consume_and_compare_commitment_value(combatant_id, (attack, salt)) {
                world.append_salt(game.combat_id, salt);
                world.set_planned_attack(combatant_id, attack, opponent_id);
                if world.check_commitment_set(opponent_id) {
                    world.set_last_timestamp(game.combat_id);
                }
            }
        }
        fn run(ref self: ContractState, combat_id: felt252) {
            let mut world = self.get_storage();

            world.run_round(world.get_owners_game(combat_id, get_contract_address()));
        }

        fn kick_player(ref self: ContractState, combat_id: felt252) {
            let mut storage = self.get_storage();
            let game = storage.get_game_info(combat_id);
            let (a, b) = game.combatant_ids;
            storage.assert_past_time_limit(game);

            let xor = match storage.get_combat_phase(game.combat_id) {
                Phase::Commit => true,
                Phase::Reveal => false,
                _ => { panic!("Game not running") }
            };

            let are_set: (bool, bool) = storage
                .check_commitments_are(game.combatant_ids.span(), xor)
                .try_into()
                .unwrap();
            let winner = match are_set {
                (true, false) => a,
                (false, true) => b,
                (true, true) => panic!("Both players have played"),
                (false, false) => panic!("Neither players have played"),
            };
            storage.set_combat_winner(combat_id, winner);
        }

        fn get_winner(ref self: ContractState, combat_id: felt252) -> ContractAddress {
            let storage = self.get_storage();
            storage.get_winning_player(combat_id)
        }
    }
}
