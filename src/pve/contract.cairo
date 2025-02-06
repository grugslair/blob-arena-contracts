use starknet::ContractAddress;
use blob_arena::{stats::UStats, collections::blobert::{TokenAttributes, BlobertItemKey}};


#[starknet::interface]
trait IPVE<TContractState> {
    fn attack(ref self: TContractState, game_id: felt252, attack: felt252);
    fn start_challenge(
        ref self: TContractState,
        challenge_id: felt252,
        collection_address: ContractAddress,
        token_id: u256,
        attacks: Array<(felt252, felt252)>,
    );
    fn next_challenge_round(ref self: TContractState, attempt_id: felt252);
    fn respawn_challenge(ref self: TContractState, attempt_id: felt252);
    fn end_challenge(ref self: TContractState, attempt_id: felt252);
    fn claim_free_game(ref self: TContractState);
}


#[dojo::contract]
mod pve_blobert_actions {
    use starknet::{ContractAddress, get_caller_address};
    use dojo::world::WorldStorage;
    use blob_arena::{
        pve::{PVETrait, PVEStorage, pve_namespace, PVEStore}, world::{uuid, default_namespace},
        game::GameProgress, utils::get_transaction_hash, stats::UStats,
        collections::blobert::{TokenAttributes, BlobertItemKey, BlobertStorage},
    };
    use super::{IPVE};
    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn get_storage(self: @ContractState) -> PVEStore {
            PVEStore { ba: self.world(default_namespace()), pve: self.get_pve_storage() }
        }
        fn get_pve_storage(self: @ContractState) -> WorldStorage {
            self.world(pve_namespace())
        }
    }

    #[abi(embed_v0)]
    impl IPVEImpl of IPVE<ContractState> {
        fn attack(ref self: ContractState, game_id: felt252, attack: felt252) {
            let mut store = self.get_storage();
            let game = store.pve.get_pve_game(game_id);
            assert(game.player == get_caller_address(), 'Not player');
            let randomness = get_transaction_hash(); //TODO: Use real randomness
            store.run_pve_round(game, attack, randomness);
        }
        fn start_challenge(
            ref self: ContractState,
            challenge_id: felt252,
            collection_address: ContractAddress,
            token_id: u256,
            attacks: Array<(felt252, felt252)>,
        ) {
            let mut store = self.get_storage();
            store
                .new_pve_challenge_attempt(
                    challenge_id, get_caller_address(), collection_address, token_id, attacks,
                );
        }
        fn next_challenge_round(ref self: ContractState, attempt_id: felt252) {
            let mut store = self.get_storage();
            let attempt = store.pve.get_pve_players_challenge_attempt(attempt_id);
            store.next_pve_challenge_round(attempt);
        }
        fn respawn_challenge(ref self: ContractState, attempt_id: felt252) {
            let mut store = self.get_storage();
            store
                .respawn_pve_challenge_attempt(
                    store.pve.get_pve_players_challenge_attempt(attempt_id),
                );
        }
        fn end_challenge(ref self: ContractState, attempt_id: felt252) {
            let mut store = self.get_pve_storage();
            let attempt = store.get_pve_challenge_attempt_end_schema(attempt_id);

            assert(attempt.player == get_caller_address(), 'Not player');

            store.end_pve_challenge_attempt(attempt_id, attempt);
        }

        fn claim_free_game(ref self: ContractState) {
            let mut store = self.get_pve_storage();
            store.mint_free_game(get_caller_address());
        }
    }
}
