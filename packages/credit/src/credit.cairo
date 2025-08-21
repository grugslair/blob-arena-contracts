use starknet::ContractAddress;

#[starknet::interface]
pub trait IArenaCredits<TState> {
    fn energy(self: @TState, user: ContractAddress) -> u64;
    fn credits(self: @TState, user: ContractAddress) -> u128;
    fn max_energy(self: @TState) -> u64;

    fn try_consume_energy(ref self: TState, user: ContractAddress, amount: u64) -> bool;
    fn consume_energy(ref self: TState, user: ContractAddress, amount: u64);
    fn try_consume_credits(ref self: TState, user: ContractAddress, amount: u128) -> bool;
    fn consume_credits(ref self: TState, user: ContractAddress, amount: u128);
    fn consume(ref self: TState, user: ContractAddress, energy: u64, credits: u128);
    fn try_consume(ref self: TState, user: ContractAddress, energy: u64, credits: u128) -> bool;


    fn set_max_energy(ref self: TState, max_energy: u64);
    fn add_credits(ref self: TState, user: ContractAddress, amount: u128);
}

pub fn arena_credit_add_credits(
    contract_address: ContractAddress, user: ContractAddress, amount: u128,
) {
    IArenaCreditsDispatcher { contract_address }.add_credits(user, amount);
}

pub fn arena_credit_consume(
    contract_address: ContractAddress, user: ContractAddress, energy: u64, credits: u128,
) {
    IArenaCreditsDispatcher { contract_address }.consume(user, energy, credits);
}


#[starknet::contract]
mod arena_credit {
    use beacon_library::{ToriiTable, register_table_with_schema};
    use core::cmp::min;
    use sai_access::{AccessTrait, access_component};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp};
    use super::IArenaCredits;

    component!(path: access_component, storage: access, event: AccessEvents);

    const ARENA_CREDIT_TABLE_ID: felt252 = bytearrays_hash!("arcade", "ArenaCredit");
    impl ArenaCreditTable = ToriiTable<ARENA_CREDIT_TABLE_ID>;

    #[derive(Drop, Serde, Introspect)]
    struct ArenaCredit {
        energy: Energy,
        credits: u128,
    }

    #[derive(Drop, Serde, Introspect)]
    struct Energy {
        timestamp: u64,
        amount: u64,
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        access: access_component::Storage,
        max_energy: u64,
        energies: Map<ContractAddress, [u64; 2]>,
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
        register_table_with_schema::<ArenaCredit>("arcade", "ArenaCredit");
    }

    #[abi(embed_v0)]
    impl IAccessImpl = access_component::AccessImpl<ContractState>;

    #[abi(embed_v0)]
    impl IArenaCreditsImpl of IArenaCredits<ContractState> {
        fn energy(self: @ContractState, user: ContractAddress) -> u64 {
            self.read_energy(user, get_block_timestamp())
        }

        fn credits(self: @ContractState, user: ContractAddress) -> u128 {
            self.credits.read(user)
        }

        fn max_energy(self: @ContractState) -> u64 {
            self.max_energy.read()
        }

        fn consume_energy(ref self: ContractState, user: ContractAddress, amount: u64) {
            self.assert_caller_is_writer();
            assert!(self.consume_energy_internal(user, amount), "Insufficient energy");
        }

        fn try_consume_energy(ref self: ContractState, user: ContractAddress, amount: u64) -> bool {
            self.assert_caller_is_writer();
            self.consume_energy_internal(user, amount)
        }

        fn consume_credits(ref self: ContractState, user: ContractAddress, amount: u128) {
            self.assert_caller_is_writer();
            assert!(self.consume_credits_internal(user, amount), "Insufficient credits");
        }

        fn try_consume_credits(
            ref self: ContractState, user: ContractAddress, amount: u128,
        ) -> bool {
            self.assert_caller_is_writer();
            self.consume_credits_internal(user, amount)
        }

        fn consume(ref self: ContractState, user: ContractAddress, energy: u64, credits: u128) {
            self.assert_caller_is_writer();
            assert(
                self.try_consume_energy(user, energy) || self.try_consume_credits(user, credits),
                'Insufficient energy and credits',
            );
        }

        fn try_consume(
            ref self: ContractState, user: ContractAddress, energy: u64, credits: u128,
        ) -> bool {
            self.assert_caller_is_writer();
            self.try_consume_energy(user, energy) || self.try_consume_credits(user, credits)
        }

        fn set_max_energy(ref self: ContractState, max_energy: u64) {
            self.assert_caller_is_owner();
            self.max_energy.write(max_energy);
        }

        fn add_credits(ref self: ContractState, user: ContractAddress, amount: u128) {
            self.assert_caller_is_writer();
            self.set_credits(user, self.credits.read(user) + amount);
        }
    }


    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn read_energy(
            self: @ContractState, contract_address: ContractAddress, current_timestamp: u64,
        ) -> u64 {
            let [timestamp, energy] = self.energies.read(contract_address);
            min(current_timestamp - timestamp + energy, self.max_energy.read())
        }

        fn consume_energy_internal(
            ref self: ContractState, user: ContractAddress, amount: u64,
        ) -> bool {
            let current_timestamp = get_block_timestamp();
            let current_energy = self.read_energy(user, current_timestamp);
            if amount <= current_energy {
                self.set_energy(user, current_timestamp, current_energy - amount);
                true
            } else {
                false
            }
        }

        fn consume_credits_internal(
            ref self: ContractState, user: ContractAddress, amount: u128,
        ) -> bool {
            let current_credits = self.credits.read(user);
            if amount <= current_credits {
                self.set_credits(user, current_credits - amount);
                true
            } else {
                false
            }
        }

        fn set_energy(ref self: ContractState, user: ContractAddress, timestamp: u64, amount: u64) {
            self.energies.write(user, [timestamp, amount]);
            ArenaCreditTable::set_member(selector!("energy"), user, @Energy { amount, timestamp });
        }

        fn set_credits(ref self: ContractState, user: ContractAddress, credits: u128) {
            self.credits.write(user, credits);
            ArenaCreditTable::set_member(selector!("credits"), user, @credits);
        }
    }
}
