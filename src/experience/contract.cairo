#[starknet::contract]
mod experience {
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::Map;
    use super::super::systems::{ExperienceTrait, experience_key, token_key, collection_player_key};
    use super::super::interface::{IExperience, IExperienceMintBurn, IExperienceAdmin};


    #[storage]
    struct Storage {
        world_address: ContractAddress,
        experience: Map<felt252, u128>,
        collection_experience: Map<ContractAddress, u128>,
        player_experience: Map<ContractAddress, u128>,
        collection_player_experience: Map<felt252, u128>,
        token_experience: Map<felt252, u128>,
        total_experience: u128,
        admins: Map<ContractAddress, bool>,
        writers: Map<ContractAddress, bool>,
    }

    #[abi(embed_v0)]
    impl IExperienceImpl of IExperience<ContractState> {
        fn experience(
            ref self: ContractState,
            collection: ContractAddress,
            token_id: u256,
            player: ContractAddress,
        ) -> u128 {
            self.experience.read(experience_key(collection, token_id, player))
        }
        fn token_experience(
            ref self: ContractState, collection: ContractAddress, token_id: u256,
        ) -> u128 {
            self.token_experience.read(token_key(collection, token_id))
        }
        fn collection_player_experience(
            ref self: ContractState, collection: ContractAddress, player: ContractAddress,
        ) -> u128 {
            self.collection_player_experience.read(collection_player_key(collection, player))
        }
        fn player_experience(ref self: ContractState, player: ContractAddress) -> u128 {
            self.player_experience.read(player)
        }
        fn collection_experience(ref self: ContractState, collection: ContractAddress) -> u128 {
            self.collection_experience.read(collection)
        }

        fn total_experience(ref self: ContractState) -> u128 {
            self.total_experience.read()
        }
    }

    #[abi(embed_v0)]
    impl IExperienceMintBurnImpl of IExperienceMintBurn<ContractState> {
        fn mint_to(
            ref self: ContractState,
            collection: ContractAddress,
            token_id: u256,
            player: ContractAddress,
            amount: u128,
        ) {
            assert(self.admins.read(get_caller_address()), 'Not admin');
            self.increase_experience(collection, token_id, player, amount);
        }
        fn burn_from(
            ref self: ContractState,
            collection: ContractAddress,
            token_id: u256,
            player: ContractAddress,
            amount: u128,
        ) {
            assert(self.admins.read(get_caller_address()), 'Not admin');
            self.decrease_experience(collection, token_id, player, amount);
        }
    }

    #[abi(embed_v0)]
    impl IExperienceAdminImpl of IExperienceAdmin<ContractState> {
        fn set_admin(ref self: ContractState, user: ContractAddress, is_admin: bool) {
            assert(self.admins.read(get_caller_address()), 'Not admin');
            self.admins.write(user, is_admin);
        }
        fn set_writer(ref self: ContractState, user: ContractAddress, is_writer: bool) {
            assert(self.admins.read(get_caller_address()), 'Not admin');
            self.writers.write(user, is_writer);
        }
        fn set_collection_cap(ref self: ContractState, collection: ContractAddress, cap: u128) {
            assert(self.admins.read(get_caller_address()), 'Not admin');
        }
    }
}
