use starknet::ContractAddress;
use blob_arena::{stats::UStats, collections::blobert::{TokenAttributes, BlobertItemKey}};


#[starknet::interface]
trait IPVE<TContractState> {
    fn attack(ref self: TContractState, game_id: felt252, attack: felt252);
}

#[starknet::interface]
trait IPVEAdmin<TContractState> {
    fn new_opponent(
        ref self: TContractState,
        name: ByteArray,
        collection: ContractAddress,
        attributes: TokenAttributes,
        stats: UStats,
        attacks: Array<felt252>,
        collections_allowed: Array<ContractAddress>,
    ) -> felt252;
    fn new_opponent_from_attack_slots(
        ref self: TContractState,
        name: ByteArray,
        collection: ContractAddress,
        attributes: TokenAttributes,
        stats: UStats,
        attack_namespace: ByteArray,
        attack_slots: Array<(BlobertItemKey, felt252)>,
        collections_allowed: Array<ContractAddress>,
    ) -> felt252;
    fn new_challenge(ref self: TContractState, health_recovery_pc: u8, opponents: Array<felt252>){
        

    }
    fn set_collection(
        ref self: TContractState, id: felt252, collection: ContractAddress, available: bool,
    );
    fn set_collections(
        ref self: TContractState, id: felt252, collections: Array<ContractAddress>, available: bool,
    );

    fn set_ids_collection(
        ref self: TContractState, ids: Array<felt252>, collection: ContractAddress, available: bool,
    );
}

#[starknet::interface]
trait IPVEFreeGames<TContractState> {
    fn claim_free_game(ref self: TContractState);
}

#[starknet::interface]
trait IPVE

#[dojo::contract]
mod pve_blobert_actions {
    use starknet::{ContractAddress, get_caller_address};
    use dojo::world::WorldStorage;
    use blob_arena::{
        pve::{PVETrait, PVEStorage, pve_namespace, PVEStore}, world::{uuid, default_namespace},
        game::GameProgress, utils::get_transaction_hash, stats::UStats,
        collections::blobert::{TokenAttributes, BlobertItemKey, BlobertStorage},
    };
    use super::{IPVE, IPVEFreeGames, IPVEAdmin};
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
    }

    #[abi(embed_v0)]
    impl IPVEFreeGamesImpl of IPVEFreeGames<ContractState> {
        fn claim_free_game(ref self: ContractState) {
            let mut store = self.get_pve_storage();
            store.mint_free_game(get_caller_address());
        }
        fn start_free_game(
            ref self: ContractState,
            player_collection_address: ContractAddress,
            player_token_id: u256,
            player_attacks: Array<(felt252, felt252)>,
            opponent_token: felt252,
        ) -> felt252 {
            let mut store = self.get_storage();
            store.pve.use_free_game(get_caller_address());
            store
                .new_pve_game(
                    get_caller_address(),
                    player_collection_address,
                    player_token_id,
                    player_attacks,
                    opponent_token,
                )
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
            collections_allowed: Array<ContractAddress>,
        ) -> felt252 {
            let mut store = self.get_pve_storage();
            store
                .setup_new_opponent(
                    name, collection, attributes, stats, attacks, collections_allowed,
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
            collections_allowed: Array<ContractAddress>,
        ) -> felt252 {
            let mut store = self.get_pve_storage();
            let attacks = self
                .world(@attack_namespace)
                .get_blobert_attack_slots(attack_slots.span());
            let token_id = store
                .setup_new_opponent(
                    name, collection, attributes, stats, attacks, collections_allowed,
                );
            token_id
        }
        fn set_collection(
            ref self: TContractState, id: felt252, collection: ContractAddress, available: bool,
        ) {
            let mut store = self.get_pve_storage();
            store.set_collection_allowed(id, collection, available);
        }
        fn set_collections(
            ref self: TContractState,
            id: felt252,
            collections: Array<ContractAddress>,
            available: bool,
        ) {
            let mut store = self.get_pve_storage();
            store.set_collections_allowed(id, collections, available);
        }
        fn set_ids_collection(
            ref self: TContractState,
            ids: Array<felt252>,
            collection: ContractAddress,
            available: bool,
        ) {
            let mut store = self.get_pve_storage();
            store.set_multiple_allowed(ids, collection, available);
        }
    }
}
