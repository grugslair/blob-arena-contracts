use starknet::ContractAddress;
use crate::stats::UStats;

#[starknet::interface]
trait IExperienceActions<TContractState> {
    fn experience(
        self: @TContractState, collection: ContractAddress, token: u256, player: ContractAddress,
    ) -> u128;
    fn token_experience(self: @TContractState, collection: ContractAddress, token: u256) -> u128;
    fn collection_player_experience(
        self: @TContractState, collection: ContractAddress, player: ContractAddress,
    ) -> u128;
    fn player_experience(self: @TContractState, player: ContractAddress) -> u128;
    fn collection_experience(self: @TContractState, collection: ContractAddress) -> u128;
    fn total_experience(self: @TContractState) -> u128;

    fn set_experience_cap(ref self: TContractState, collection: ContractAddress, cap: u128);
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
    use crate::stats::UStats;
    use crate::world::WorldTrait;
    use super::IExperienceActions;
    use super::super::{ExperienceStorage, ExperienceTrait};

    #[storage]
    struct Storage {
        player_token: Map<(felt252, ContractAddress), u128>,
        player_collection: Map<(ContractAddress, ContractAddress), u128>,
        token: Map<felt252, u128>,
        collection: Map<ContractAddress, u128>,
        player: Map<ContractAddress, u128>,
        total_experience: u128,
    }

    #[abi(embed_v0)]
    impl IExperienceActionsImpl of IExperienceActions<ContractState> {
        fn experience(
            self: @ContractState, collection: ContractAddress, token: u256, player: ContractAddress,
        ) -> u128 {
            self.experience_storage().get_experience_value(collection, token, player)
        }
        fn token_experience(
            self: @ContractState, collection: ContractAddress, token: u256,
        ) -> u128 {
            self.experience_storage().get_token_experience(collection, token)
        }
        fn collection_player_experience(
            self: @ContractState, collection: ContractAddress, player: ContractAddress,
        ) -> u128 {
            self.experience_storage().get_collection_player_experience(collection, player)
        }
        fn player_experience(self: @ContractState, player: ContractAddress) -> u128 {
            self.experience_storage().get_player_experience(player)
        }
        fn collection_experience(self: @ContractState, collection: ContractAddress) -> u128 {
            self.experience_storage().get_collection_experience(collection)
        }
        fn total_experience(self: @ContractState) -> u128 {
            self.experience_storage().get_total_experience()
        }

        fn set_experience_cap(ref self: ContractState, collection: ContractAddress, cap: u128) {
            let mut storage = self.experience_storage();
            storage.set_experience_cap(collection, cap);
        }
    }
}
