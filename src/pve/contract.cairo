use starknet::ContractAddress;
use blob_arena::{stats::UStats, collections::blobert::{TokenAttributes, BlobertItemKey}};


/// Interface for Player vs Environment (PVE) contract.
///
/// # Methods
/// - `new_game`: Starts a new game session.
/// - `attack`: Executes an attack in an ongoing game.
///
/// ## `new_game`
/// Starts a new game session.
///
/// ### Parameters:
/// - `player_collection_address`: Address of the player's collection contract.
/// - `player_token_id`: Token ID of the player.
/// - `player_attacks`: Array of tuples representing the player's attacks. Each tuple contains two
/// `felt252` values.
/// - `opponent_token`: Token ID of the opponent.
///
/// ### Returns:
/// - `felt252`: A unique identifier for the newly created game.
///
/// ## `attack`
/// Executes an attack in an ongoing game.
///
/// ### Parameters:
/// - `game_id`: Unique identifier of the game.
/// - `attack`: Attack identifier represented as `felt252`.
#[starknet::interface]
trait IPVE<TContractState> {
    fn new_game(
        ref self: TContractState,
        player_collection_address: ContractAddress,
        player_token_id: u256,
        player_attacks: Array<(felt252, felt252)>,
        opponent_token: felt252
    ) -> felt252;
    fn attack(ref self: TContractState, game_id: felt252, attack: felt252);
}


/// Interface for Player vs Environment (PVE) contract administration.
///
/// # Methods
/// - `new_opponent`: Registers a new opponent.
/// - `new_opponent_from_attack_slots`: Registers a new opponent using attack slots.
/// - `set_opponent_collection`: Sets the collection availability for an opponent.
/// - `set_opponent_collections`: Sets the collection availability for multiple collections for an
/// opponent.
/// - `set_opponents_collection`: Sets the collection availability for multiple opponents.
///
/// ## `new_opponent`
/// Registers a new opponent.
///
/// ### Parameters:
/// - `name`: Name of the opponent.
/// - `collection`: Address of the opponent's collection contract.
/// - `attributes`: Attributes of the opponent.
/// - `stats`: Stats of the opponent.
/// - `attacks`: Array of attack identifiers.
/// - `collections_allowed`: Array of addresses of allowed collections.
///
/// ### Returns:
/// - `felt252`: A unique identifier for the newly registered opponent.
///
/// ## `new_opponent_from_attack_slots`
/// Registers a new opponent using attack slots.
///
/// ### Parameters:
/// - `name`: Name of the opponent.
/// - `collection`: Address of the opponent's collection contract.
/// - `attributes`: Attributes of the opponent.
/// - `stats`: Stats of the opponent.
/// - `attack_namespace`: Namespace for the attack slots.
/// - `attack_slots`: Array of tuples representing the attack slots. Each tuple contains a
/// `BlobertItemKey` and a `felt252` value.
/// - `collections_allowed`: Array of addresses of allowed collections.
///
/// ### Returns:
/// - `felt252`: A unique identifier for the newly registered opponent.
///
/// ## `set_opponent_collection`
/// Sets the collection availability for an opponent.
///
/// ### Parameters:
/// - `token_id`: Token ID of the opponent.
/// - `collection`: Address of the collection contract.
/// - `available`: Boolean indicating if the collection is available.
///
/// ## `set_opponent_collections`
/// Sets the collection availability for multiple collections for an opponent.
///
/// ### Parameters:
/// - `token_id`: Token ID of the opponent.
/// - `collections`: Array of addresses of the collection contracts.
/// - `available`: Boolean indicating if the collections are available.
///
/// ## `set_opponents_collection`
/// Sets the collection availability for multiple opponents.
///
/// ### Parameters:
/// - `token_ids`: Array of token IDs of the opponents.
/// - `collection`: Address of the collection contract.
/// - `available`: Boolean indicating if the collection is available.
#[starknet::interface]
trait IPVEAdmin<TContractState> {
    fn new_opponent(
        ref self: TContractState,
        name: ByteArray,
        collection: ContractAddress,
        attributes: TokenAttributes,
        stats: UStats,
        attacks: Array<felt252>,
        collections_allowed: Array<ContractAddress>
    ) -> felt252;
    fn new_opponent_from_attack_slots(
        ref self: TContractState,
        name: ByteArray,
        collection: ContractAddress,
        attributes: TokenAttributes,
        stats: UStats,
        attack_namespace: ByteArray,
        attack_slots: Array<(BlobertItemKey, felt252)>,
        collections_allowed: Array<ContractAddress>
    ) -> felt252;
    fn set_opponent_collection(
        ref self: TContractState, token_id: felt252, collection: ContractAddress, available: bool
    );
    fn set_opponent_collections(
        ref self: TContractState,
        token_id: felt252,
        collections: Array<ContractAddress>,
        available: bool
    );

    fn set_opponents_collection(
        ref self: TContractState,
        token_ids: Array<felt252>,
        collection: ContractAddress,
        available: bool
    );
}

#[dojo::contract]
mod pve_blobert_actions {
    use starknet::{ContractAddress, get_caller_address};
    use dojo::world::WorldStorage;
    use blob_arena::{
        pve::{PVETrait, PVEStorage, pve_namespace, PVEStore}, world::{uuid, default_namespace},
        game::GameProgress, utils::get_transaction_hash, stats::UStats,
        collections::blobert::{TokenAttributes, BlobertItemKey, BlobertStorage}
    };
    use super::{IPVE, IPVEAdmin};
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
        fn new_game(
            ref self: ContractState,
            player_collection_address: ContractAddress,
            player_token_id: u256,
            player_attacks: Array<(felt252, felt252)>,
            opponent_token: felt252
        ) -> felt252 {
            let mut store = self.get_storage();
            store
                .new_pve_game(
                    get_caller_address(),
                    player_collection_address,
                    player_token_id,
                    player_attacks,
                    opponent_token
                )
        }
        fn attack(ref self: ContractState, game_id: felt252, attack: felt252) {
            let mut store = self.get_storage();
            let game = store.pve.get_pve_game(game_id);
            assert(game.player == get_caller_address(), 'Not player');
            let randomness = get_transaction_hash(); //TODO: Use real randomness
            store.run_pve_round(game, attack, randomness);
        }
    }

    #[abi(embed_v0)]
    impl IPVEAdminImpl of IPVEAdmin<ContractState> {
        fn new_opponent(
            ref self: ContractState,
            name: ByteArray,
            collection: ContractAddress,
            attributes: TokenAttributes,
            stats: UStats,
            attacks: Array<felt252>,
            collections_allowed: Array<ContractAddress>
        ) -> felt252 {
            let mut store = self.get_pve_storage();
            store
                .setup_new_opponent(
                    name, collection, attributes, stats, attacks, collections_allowed
                )
        }
        fn new_opponent_from_attack_slots(
            ref self: ContractState,
            name: ByteArray,
            collection: ContractAddress,
            attributes: TokenAttributes,
            stats: UStats,
            attack_namespace: ByteArray,
            attack_slots: Array<(BlobertItemKey, felt252)>,
            collections_allowed: Array<ContractAddress>
        ) -> felt252 {
            let mut store = self.get_pve_storage();
            let attacks = self
                .world(@attack_namespace)
                .get_blobert_attack_slots(attack_slots.span());
            let token_id = store
                .setup_new_opponent(
                    name, collection, attributes, stats, attacks, collections_allowed
                );
            token_id
        }
        fn set_opponent_collection(
            ref self: ContractState, token_id: felt252, collection: ContractAddress, available: bool
        ) {
            let mut store = self.get_pve_storage();
            store.set_collection_allowed(token_id, collection, available);
        }
        fn set_opponent_collections(
            ref self: ContractState,
            token_id: felt252,
            collections: Array<ContractAddress>,
            available: bool
        ) {
            let mut store = self.get_pve_storage();
            store.set_collections_allowed(token_id, collections, available);
        }
        fn set_opponents_collection(
            ref self: ContractState,
            token_ids: Array<felt252>,
            collection: ContractAddress,
            available: bool
        ) {
            let mut store = self.get_pve_storage();
            store.set_mutiple_collection_allowed(token_ids, collection, available);
        }
    }
}
