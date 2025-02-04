use starknet::ContractAddress;
#[starknet::interface]
trait IPVEFreeGames<TContractState> {
    fn claim_free_game(ref self: TContractState);
    fn start_free_game(
        ref self: TContractState,
        player_collection_address: ContractAddress,
        player_token_id: u256,
        player_attacks: Array<(felt252, felt252)>,
        opponent_token: felt252,
    ) -> felt252;
}

#[dojo::contract]
mod pve_blobert_free_game_actions {
    use starknet::{get_caller_address, ContractAddress};
    use dojo::world::WorldStorage;

    use blob_arena::pve::{PVETrait, PVEStore, pve_namespace};

    use super::{IPVEFreeGames};
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
    impl IPVEFreeGamesImpl of IPVEFreeGames<ContractState> {
        fn claim_game(ref self: ContractState) {
            let mut store = self.get_pve_storage();
            store.mint_free_game(get_caller_address());
        }
        fn start(
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
}
