use starknet::ContractAddress;

#[starknet::interface]
trait IArcadeFuel<TState> {
    fn fuel(self: @TState, user: ContractAddress) -> u64;
    fn credits(self: @TState, user: ContractAddress) -> u128;
    fn max_fuel(self: @TState) -> u64;

    fn withdraw(ref self: TState, user: ContractAddress, fuel_cost: u64, credits_cost: u128);
    fn try_withdraw(
        ref self: TState, user: ContractAddress, fuel_cost: u64, credits_cost: u128,
    ) -> bool;

    fn set_max_fuel(ref self: TState, max_fuel: u64);
    fn add_credits(ref self: TState, user: ContractAddress, amount: u128);
}


#[starknet::contract]
mod arcade_fuel {
    use beacon_library::{ToriiTable, register_table_with_schema};
    use core::cmp::min;
    use sai_access::{AccessTrait, access_component};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp};
    use super::IArcadeFuel;

    component!(path: access_component, storage: access, event: AccessEvents);

    const ARCADE_FUEL_TABLE_ID: felt252 = bytearrays_hash!("arcade", "ArcadeFuel");
    impl ArcadeFuelTable = ToriiTable<ARCADE_FUEL_TABLE_ID>;

    #[derive(Drop, Serde, Introspect)]
    struct ArcadeFuel {
        timestamp: u64,
        fuel: u64,
        credits: u128,
    }

    #[derive(Drop, Serde, Introspect, Schema)]
    struct FuelSchema {
        timestamp: u64,
        fuel: u64,
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        access: access_component::Storage,
        max_fuel: u64,
        fuel: Map<ContractAddress, [u64; 2]>,
        credits: Map<ContractAddress, u128>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccessEvents: access_component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.grant_owner(owner);
        register_table_with_schema::<ArcadeFuel>("arcade", "ArcadeFuel");
    }

    #[abi(embed_v0)]
    impl IAccessImpl = access_component::AccessImpl<ContractState>;

    #[abi(embed_v0)]
    impl IArcadeFuelImpl of IArcadeFuel<ContractState> {
        fn fuel(self: @ContractState, user: ContractAddress) -> u64 {
            self.read_fuel(user, get_block_timestamp())
        }

        fn credits(self: @ContractState, user: ContractAddress) -> u128 {
            self.credits.read(user)
        }

        fn max_fuel(self: @ContractState) -> u64 {
            self.max_fuel.read()
        }

        fn withdraw(
            ref self: ContractState, user: ContractAddress, fuel_cost: u64, credits_cost: u128,
        ) {
            self.assert_caller_is_writer();
            let current_timestamp = get_block_timestamp();
            let fuel = self.read_fuel(user, current_timestamp);
            if fuel_cost <= fuel {
                self.set_fuel(user, current_timestamp, fuel - fuel_cost);
            } else {
                let credits = self.credits.read(user);
                if credits_cost <= credits {
                    self.set_credits(user, credits - credits_cost);
                } else {
                    panic!("Insufficient fuel and credits");
                }
            }
        }

        fn try_withdraw(
            ref self: ContractState, user: ContractAddress, fuel_cost: u64, credits_cost: u128,
        ) -> bool {
            self.assert_caller_is_writer();
            let current_timestamp = get_block_timestamp();
            let fuel = self.read_fuel(user, current_timestamp);
            if fuel_cost <= fuel {
                self.set_fuel(user, current_timestamp, fuel - fuel_cost);
                true
            } else {
                let credits = self.credits.read(user);
                if credits_cost <= credits {
                    self.set_credits(user, credits - credits_cost);
                    true
                } else {
                    false
                }
            }
        }

        fn set_max_fuel(ref self: ContractState, max_fuel: u64) {
            self.assert_caller_is_owner();
            self.max_fuel.write(max_fuel);
        }

        fn add_credits(ref self: ContractState, user: ContractAddress, amount: u128) {
            self.assert_caller_is_writer();
            self.set_credits(user, self.credits.read(user) + amount);
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


        fn set_fuel(
            ref self: ContractState, contract_address: ContractAddress, timestamp: u64, fuel: u64,
        ) {
            self.fuel.write(contract_address, [timestamp, fuel]);
            ArcadeFuelTable::set_schema(contract_address, @FuelSchema { timestamp, fuel });
        }

        fn set_credits(ref self: ContractState, contract_address: ContractAddress, credits: u128) {
            self.credits.write(contract_address, credits);
            ArcadeFuelTable::set_member(selector!("credits"), contract_address, @credits);
        }
    }
}
