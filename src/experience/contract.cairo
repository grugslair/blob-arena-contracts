use starknet::ContractAddress;
use crate::stats::UStats;

#[starknet::interface]
trait IExperienceActions<TContractState> {
    fn get_experience(
        self: @TContractState, collection: ContractAddress, token: u256, player: ContractAddress,
    ) -> u128;
    fn get_token_experience(
        self: @TContractState, collection: ContractAddress, token: u256,
    ) -> u128;
    fn get_collection_player_experience(
        self: @TContractState, collection: ContractAddress, player: ContractAddress,
    ) -> u128;
    fn get_player_experience(self: @TContractState, player: ContractAddress) -> u128;
    fn get_collection_experience(self: @TContractState, collection: ContractAddress) -> u128;
    fn get_total_experience(self: @TContractState) -> u128;

    fn set_experience_cap(ref self: TContractState, collection: ContractAddress, cap: u128);
}

#[dojo::contract]
mod experience_actions {
    use starknet::{ContractAddress, get_caller_address};
    use crate::stats::UStats;
    use crate::world::WorldTrait;
    use super::IExperienceActions;
    use super::super::{ExperienceStorage, ExperienceTrait};

    #[abi(embed_v0)]
    impl IExperienceActionsImpl of IExperienceActions<ContractState> {
        fn get_experience(
            self: @ContractState, collection: ContractAddress, token: u256, player: ContractAddress,
        ) -> u128 {
            self.experience_storage().get_experience_value(collection, token, player)
        }
        fn get_token_experience(
            self: @ContractState, collection: ContractAddress, token: u256,
        ) -> u128 {
            self.experience_storage().get_token_experience(collection, token)
        }
        fn get_collection_player_experience(
            self: @ContractState, collection: ContractAddress, player: ContractAddress,
        ) -> u128 {
            self.experience_storage().get_collection_player_experience(collection, player)
        }
        fn get_player_experience(self: @ContractState, player: ContractAddress) -> u128 {
            self.experience_storage().get_player_experience(player)
        }
        fn get_collection_experience(self: @ContractState, collection: ContractAddress) -> u128 {
            self.experience_storage().get_collection_experience(collection)
        }
        fn get_total_experience(self: @ContractState) -> u128 {
            self.experience_storage().get_total_experience()
        }

        fn set_experience_cap(ref self: ContractState, collection: ContractAddress, cap: u128) {
            let mut storage = self.experience_storage();
            storage.set_experience_cap(collection, cap);
        }
        fn allocate_stats(
            ref self: ContractState, collection: ContractAddress, token: u256, stats: UStats,
        ) {
            let mut dispatcher = self.world_dispatcher();
            dispatcher.allocate_experience_stats(collection, token, get_caller_address(), stats);
        }
        fn remove_overflowing_stats(
            ref self: ContractState, collection: ContractAddress, token: u256,
        ) {
            let mut dispatcher = self.world_dispatcher();
            dispatcher.remove_overflowing_experience_stats(collection, token, get_caller_address());
        }
    }
}
