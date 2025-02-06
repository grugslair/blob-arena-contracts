use starknet::ContractAddress;
use blob_arena::{stats::UStats, collections::blobert::{TokenAttributes, BlobertItemKey}};

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
    fn new_challenge(
        ref self: TContractState,
        name: ByteArray,
        health_recovery_pc: u8,
        opponents: Array<felt252>,
        collections_allowed: Array<ContractAddress>,
    );
    fn set_collection(
        ref self: TContractState, id: felt252, collection: ContractAddress, available: bool,
    );
    fn set_collections(
        ref self: TContractState, id: felt252, collections: Array<ContractAddress>, available: bool,
    );

    fn set_ids_collection(
        ref self: TContractState, ids: Array<felt252>, collection: ContractAddress, available: bool,
    );
    fn mint_free_games(ref self: TContractState, player: ContractAddress, amount: u32);
}

#[dojo::contract]
mod pve_blobert_admin_actions {
    use starknet::{ContractAddress, get_caller_address};
    use dojo::world::WorldStorage;
    use blob_arena::{
        pve::{PVEStore, PVETrait, PVEStorage, pve_namespace}, stats::UStats,
        collections::blobert::{TokenAttributes, BlobertItemKey, BlobertStorage},
    };
    use super::IPVEAdmin;

    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn get_pve_storage(self: @ContractState) -> WorldStorage {
            self.world(pve_namespace())
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
        fn new_challenge(
            ref self: ContractState,
            name: ByteArray,
            health_recovery_pc: u8,
            opponents: Array<felt252>,
            collections_allowed: Array<ContractAddress>,
        ) {
            let mut store = self.get_pve_storage();
            store.setup_new_challenge(name, health_recovery_pc, opponents, collections_allowed);
        }
        fn set_collection(
            ref self: ContractState, id: felt252, collection: ContractAddress, available: bool,
        ) {
            let mut store = self.get_pve_storage();
            store.set_collection_allowed(id, collection, available);
        }
        fn set_collections(
            ref self: ContractState,
            id: felt252,
            collections: Array<ContractAddress>,
            available: bool,
        ) {
            let mut store = self.get_pve_storage();
            store.set_collections_allowed(id, collections, available);
        }
        fn set_ids_collection(
            ref self: ContractState,
            ids: Array<felt252>,
            collection: ContractAddress,
            available: bool,
        ) {
            let mut store = self.get_pve_storage();
            store.set_multiple_collection_allowed(ids, collection, available);
        }
        fn mint_free_games(ref self: ContractState, player: ContractAddress, amount: u32) {
            let mut store = self.get_pve_storage();
            let mut model = store.get_free_games(player);
            model.games += amount;
            if model.last_claim.is_non_zero() {
                store.set_number_free_games(player, model.games);
            } else {
                store.set_free_games_model(model)
            }
        }
    }
}
