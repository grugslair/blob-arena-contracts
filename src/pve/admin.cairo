use starknet::ContractAddress;
use blob_arena::{
    stats::UStats, pve::PVEOpponentInput, collections::blobert::{TokenAttributes, BlobertItemKey},
    tags::IdTagNew, attacks::components::AttackInput,
};

#[starknet::interface]
trait IPVEAdmin<TContractState> {
    fn new_opponent(
        ref self: TContractState,
        name: ByteArray,
        collection: ContractAddress,
        attributes: TokenAttributes,
        stats: UStats,
        attacks: Array<IdTagNew<AttackInput>>,
        collections_allowed: Array<ContractAddress>,
    ) -> felt252;
    fn new_challenge(
        ref self: TContractState,
        name: ByteArray,
        health_recovery_pc: u8,
        opponents: Array<IdTagNew<PVEOpponentInput>>,
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
    fn mint_paid_games(ref self: TContractState, player: ContractAddress, amount: u32);
}

#[dojo::contract]
mod pve_blobert_admin_actions {
    use starknet::{ContractAddress, get_caller_address};
    use dojo::world::WorldStorage;
    use blob_arena::{
        attacks::{AttackInput, AttackTrait}, permissions::GamePermissions,
        pve::{PVEStore, PVETrait, PVEStorage, PVE_NAMESPACE_HASH, PVEOpponentInput}, stats::UStats,
        collections::blobert::{TokenAttributes, BlobertItemKey, BlobertStorage}, tags::IdTagNew,
        world::DEFAULT_NAMESPACE_HASH,
    };
    use super::IPVEAdmin;

    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn get_pve_storage(self: @ContractState) -> WorldStorage {
            self.world_ns_hash(DEFAULT_NAMESPACE_HASH).assert_caller_is_admin();
            self.world_ns_hash(PVE_NAMESPACE_HASH)
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
            attacks: Array<IdTagNew<AttackInput>>,
            collections_allowed: Array<ContractAddress>,
        ) -> felt252 {
            let mut store = self.get_pve_storage();
            let attack_ids = store.create_or_get_attacks_external(attacks);
            store
                .setup_new_opponent(
                    name, collection, attributes, stats, attack_ids, collections_allowed,
                )
        }
        fn new_challenge(
            ref self: ContractState,
            name: ByteArray,
            health_recovery_pc: u8,
            opponents: Array<IdTagNew<PVEOpponentInput>>,
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
                store.set_number_of_free_games(player, model.games);
            } else {
                store.set_free_games_model(model)
            }
        }
        fn mint_paid_games(ref self: ContractState, player: ContractAddress, amount: u32) {
            let mut store = self.get_pve_storage();
            let games = store.get_number_of_paid_games(player);
            store.set_number_of_paid_games(player, games + amount);
        }
    }
}
