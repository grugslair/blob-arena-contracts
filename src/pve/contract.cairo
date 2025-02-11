use starknet::ContractAddress;
use blob_arena::{stats::UStats, collections::blobert::{TokenAttributes, BlobertItemKey}};


/// Interface for the PVE (Player vs Environment) game contract
///
/// # Functions
///
/// * `start_game` - Initiates a new PVE game session
///   * `opponent_id` - Identifier for the opponent to fight
///   * `collection_address` - Contract address of the NFT collection
///   * `token_id` - ID of the token being used
///   * `attacks` - Array of attack tuples (attack_type, attack_value)
///   * Returns: game_id as felt252
///
/// * `attack` - Executes an attack in an ongoing game
///   * `game_id` - Identifier of the active game
///   * `attack_id` - The id of the attack to perform
///
/// * `start_challenge` - Begins a new challenge mode session
///   * `challenge_id` - Identifier for the specific challenge
///   * `collection_address` - Contract address of the NFT collection
///   * `token_id` - ID of the token being used
///   * `attacks` - Array of attack tuples (item_n, slot_n) where item_n is 1, 2, 3... for
///   Background, Armour, Jewelry....
///
/// * `next_challenge_round` - Advances to the next round in a challenge
///   * `attempt_id` - Identifier for the current challenge attempt
///
/// * `respawn_challenge` - Restarts a challenge attempt
///   * `attempt_id` - Identifier for the challenge attempt to respawn
///
/// * `end_challenge` - Concludes an active challenge
///   * `attempt_id` - Identifier for the challenge attempt to end
///
/// * `claim_free_game` - Claims a free game session for the player
#[starknet::interface]
trait IPVE<TContractState> {
    fn start_game(
        ref self: TContractState,
        opponent_id: felt252,
        collection_address: ContractAddress,
        token_id: u256,
        attacks: Array<(felt252, felt252)>,
    ) -> felt252;
    fn attack(ref self: TContractState, game_id: felt252, attack_id: felt252);
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
        pve::{PVETrait, PVEStorage, PVE_NAMESPACE_HASH, PVEStore},
        world::{uuid, DEFAULT_NAMESPACE_HASH}, game::GameProgress, utils::get_transaction_hash,
        stats::UStats, collections::blobert::{TokenAttributes, BlobertItemKey, BlobertStorage},
    };
    use super::{IPVE};
    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn get_storage(self: @ContractState) -> PVEStore {
            PVEStore { ba: self.world_ns_hash(DEFAULT_NAMESPACE_HASH), pve: self.get_pve_storage() }
        }
        fn get_pve_storage(self: @ContractState) -> WorldStorage {
            self.world_ns_hash(PVE_NAMESPACE_HASH)
        }
    }

    #[abi(embed_v0)]
    impl IPVEImpl of IPVE<ContractState> {
        fn start_game(
            ref self: ContractState,
            opponent_id: felt252,
            collection_address: ContractAddress,
            token_id: u256,
            attacks: Array<(felt252, felt252)>,
        ) -> felt252 {
            let mut store = self.get_storage();
            let caller = get_caller_address();
            store.pve.use_game(caller);
            store.new_pve_game(opponent_id, caller, collection_address, token_id, attacks)
        }
        fn attack(ref self: ContractState, game_id: felt252, attack_id: felt252) {
            let mut store = self.get_storage();
            let game = store.pve.get_pve_game(game_id);
            assert(game.player == get_caller_address(), 'Not player');
            let randomness = get_transaction_hash(); //TODO: Use real randomness
            store.run_pve_round(game, attack_id, randomness);
        }
        fn start_challenge(
            ref self: ContractState,
            challenge_id: felt252,
            collection_address: ContractAddress,
            token_id: u256,
            attacks: Array<(felt252, felt252)>,
        ) {
            let mut store = self.get_storage();
            let caller = get_caller_address();
            store.pve.use_game(caller);
            store
                .new_pve_challenge_attempt(
                    challenge_id, caller, collection_address, token_id, attacks,
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
