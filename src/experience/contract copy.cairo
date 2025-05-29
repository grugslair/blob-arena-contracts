use starknet::ContractAddress;
use crate::stats::UStats;

#[starknet::interface]
trait IExperienceActions<TContractState> {
    fn player_token(
        self: @TContractState, player: ContractAddress, collection: ContractAddress, token: u256,
    ) -> u128;
    fn player_collection(
        self: @TContractState, player: ContractAddress, collection: ContractAddress,
    ) -> u128;
    fn player(self: @TContractState, player: ContractAddress) -> u128;
    fn token(self: @TContractState, collection: ContractAddress, token: u256) -> u128;
    fn collection(self: @TContractState, collection: ContractAddress) -> u128;
    fn total(self: @TContractState) -> u128;
}

trait IExperienceAdmin<TContractState> {
    fn increase(
        ref self: TContractState,
        collection: ContractAddress,
        token: u256,
        player: ContractAddress,
        amount: u128,
    );
    fn decrease(
        ref self: TContractState,
        collection: ContractAddress,
        token: u256,
        player: ContractAddress,
        amount: u128,
    );
}

#[dojo::contract]
mod experience_actions {
    use starknet::{ContractAddress, get_caller_address};
    use crate::erc721::erc721_token_key;
    use crate::world::WorldTrait;
    use super::IExperienceActions;
    use super::super::storage;

    #[storage]
    struct Storage {
        emitter: ContractAddress,
    }

    #[abi(embed_v0)]
    impl IExperienceActionsImpl of IExperienceActions<ContractState> {
        fn player_token(
            self: @ContractState, collection: ContractAddress, token: u256, player: ContractAddress,
        ) -> u128 {
            storage::read_player_token_experience(player, erc721_token_key(collection, token))
        }

        fn player_collection(
            self: @ContractState, collection: ContractAddress, token: u256,
        ) -> u128 {
            storage::read_player_collection_experience(player, collection)
        }

        fn player(self: @ContractState, player: ContractAddress) -> u128 {
            storage::read_player_experience(player)
        }
        fn token(self: @ContractState, collection: ContractAddress, token: u256) -> u128 {
            storage::read_token_experience(erc721_token_key(collection, token))
        }
        fn collection(self: @ContractState, collection: ContractAddress) -> u128 {
            storage::read_collection_experience(collection)
        }
        fn total(self: @ContractState) -> u128 {
            storage::read_total_experience()
        }
    }
}
