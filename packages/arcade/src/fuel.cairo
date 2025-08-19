use starknet::ContractAddress;

#[starknet::interface]
trait IArcadeFuel<TState> {
    fn fuel(self: @TState, user: ContractAddress) -> u64;
    fn max_fuel(self: @TState) -> u64;

    fn use_fuel(ref self: TState, user: ContractAddress, amount: u64) -> bool;

    fn set_max_fuel(ref self: TState, max_fuel: u64);
}


#[starknet::contract]
mod arcade_fuel {
    use core::cmp::min;
    use sai_access::{AccessTrait, access_component};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp};
    use super::IArcadeFuel;

    component!(path: access_component, storage: access, event: AccessEvents);


    #[storage]
    struct Storage {
        #[substorage(v0)]
        access: access_component::Storage,
        max_fuel: u64,
        fuel: Map<ContractAddress, [u64; 2]>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccessEvents: access_component::Event,
    }

    #[abi(embed_v0)]
    impl IAccessImpl = access_component::AccessImpl<ContractState>;

    #[abi(embed_v0)]
    impl IArcadeFuelImpl of IArcadeFuel<ContractState> {
        fn fuel(self: @ContractState, user: ContractAddress) -> u64 {
            self.read_fuel(user, get_block_timestamp())
        }

        fn max_fuel(self: @ContractState) -> u64 {
            self.max_fuel.read()
        }

        fn use_fuel(ref self: ContractState, user: ContractAddress, amount: u64) -> bool {
            self.assert_caller_is_writer();
            let current_timestamp = get_block_timestamp();
            let fuel = self.read_fuel(user, current_timestamp);
            if fuel < amount {
                false
            } else {
                self.fuel.write(user, [current_timestamp, fuel - amount]);
                true
            }
        }

        fn set_max_fuel(ref self: ContractState, max_fuel: u64) {
            self.assert_caller_is_owner();
            self.max_fuel.write(max_fuel);
        }
    }


    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn read_fuel(
            self: @ContractState, contract_address: ContractAddress, current_timestamp: u64,
        ) -> u64 {
            let [timestamp, fuel] = self.fuel.read(contract_address);
            min(current_timestamp - timestamp + fuel, self.max_fuel.read())
        }
    }
}
