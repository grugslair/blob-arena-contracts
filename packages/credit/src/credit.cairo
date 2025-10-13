use starknet::ContractAddress;

/// Interface for managing arena credits and energy system
///
/// Provides a dual-currency system where users can spend either energy (regenerating over time)
/// or credits (persistent currency) to participate in arena activities. Energy acts as a
/// rate-limiting mechanism while credits provide an alternative payment method.
#[starknet::interface]
pub trait IArenaCredits<TState> {
    /// Gets the current energy amount for a user
    ///
    /// Energy regenerates over time up to the maximum limit. This function calculates
    /// the current energy based on time elapsed since last update.
    ///
    /// # Arguments
    /// * `user` - The address of the user to check energy for
    ///
    /// # Returns
    /// * `u64` - Current energy amount (capped at max_energy)
    fn energy(self: @TState, user: ContractAddress) -> u64;

    /// Gets the current credit balance for a user
    ///
    /// Credits are a persistent currency that does not regenerate over time.
    ///
    /// # Arguments
    /// * `user` - The address of the user to check credits for
    ///
    /// # Returns
    /// * `u128` - Current credit balance
    fn credits(self: @TState, user: ContractAddress) -> u128;

    /// Gets the maximum energy limit
    ///
    /// # Returns
    /// * `u64` - Maximum energy amount any user can have
    fn max_energy(self: @TState) -> u64;

    /// Attempts to consume energy from a user's balance
    ///
    /// # Arguments
    /// * `user` - The address of the user to consume energy from
    /// * `amount` - Amount of energy to consume
    ///
    /// # Returns
    /// * `bool` - True if energy was successfully consumed, false if insufficient
    ///
    /// # Access Control
    /// * Requires writer access
    fn try_consume_energy(ref self: TState, user: ContractAddress, amount: u64) -> bool;

    /// Consumes energy from a user's balance
    ///
    /// # Arguments
    /// * `user` - The address of the user to consume energy from
    /// * `amount` - Amount of energy to consume
    ///
    /// # Panics
    /// * If user has insufficient energy
    ///
    /// # Access Control
    /// * Requires writer access
    fn consume_energy(ref self: TState, user: ContractAddress, amount: u64);

    /// Attempts to consume credits from a user's balance
    ///
    /// # Arguments
    /// * `user` - The address of the user to consume credits from
    /// * `amount` - Amount of credits to consume
    ///
    /// # Returns
    /// * `bool` - True if credits were successfully consumed, false if insufficient
    ///
    /// # Access Control
    /// * Requires writer access
    fn try_consume_credits(ref self: TState, user: ContractAddress, amount: u128) -> bool;

    /// Consumes credits from a user's balance
    ///
    /// # Arguments
    /// * `user` - The address of the user to consume credits from
    /// * `amount` - Amount of credits to consume
    ///
    /// # Panics
    /// * If user has insufficient credits
    ///
    /// # Access Control
    /// * Requires writer access
    fn consume_credits(ref self: TState, user: ContractAddress, amount: u128);

    /// Consumes either energy or credits from a user (whichever is available)
    ///
    /// Attempts to consume energy first, then credits if energy is insufficient.
    /// Succeeds if either currency can cover the cost.
    ///
    /// # Arguments
    /// * `user` - The address of the user to consume from
    /// * `energy` - Amount of energy to attempt consuming
    /// * `credits` - Amount of credits to attempt consuming (if energy fails)
    ///
    /// # Panics
    /// * If user has insufficient energy AND insufficient credits
    ///
    /// # Access Control
    /// * Requires writer access
    fn consume(ref self: TState, user: ContractAddress, energy: u64, credits: u128);

    /// Attempts to consume either energy or credits from a user
    ///
    /// # Arguments
    /// * `user` - The address of the user to consume from
    /// * `energy` - Amount of energy to attempt consuming
    /// * `credits` - Amount of credits to attempt consuming (if energy fails)
    ///
    /// # Returns
    /// * `bool` - True if either energy or credits were successfully consumed
    ///
    /// # Access Control
    /// * Requires writer access
    fn try_consume(ref self: TState, user: ContractAddress, energy: u64, credits: u128) -> bool;

    /// Sets the maximum energy limit for all users
    ///
    /// # Arguments
    /// * `max_energy` - New maximum energy limit
    ///
    /// # Access Control
    /// * Requires owner access
    fn set_max_energy(ref self: TState, max_energy: u64);

    /// Adds credits to a user's balance
    ///
    /// # Arguments
    /// * `user` - The address of the user to add credits to
    /// * `amount` - Amount of credits to add
    ///
    /// # Access Control
    /// * Requires writer access
    fn add_credits(ref self: TState, user: ContractAddress, amount: u128);
}

/// Utility function to add credits to a user via external contract call
///
/// # Arguments
/// * `contract_address` - Address of the arena credits contract
/// * `user` - The address of the user to add credits to
/// * `amount` - Amount of credits to add
pub fn arena_credit_add_credits(
    contract_address: ContractAddress, user: ContractAddress, amount: u128,
) {
    IArenaCreditsDispatcher { contract_address }.add_credits(user, amount);
}

/// Utility function to consume energy or credits via external contract call
///
/// # Arguments
/// * `contract_address` - Address of the arena credits contract
/// * `user` - The address of the user to consume from
/// * `energy` - Amount of energy to attempt consuming
/// * `credits` - Amount of credits to consume if energy is insufficient
pub fn arena_credit_consume(
    contract_address: ContractAddress, user: ContractAddress, energy: u64, credits: u128,
) {
    IArenaCreditsDispatcher { contract_address }.consume(user, energy, credits);
}


pub fn arena_credit_consume_credits(
    contract_address: ContractAddress, user: ContractAddress, credits: u128,
) {
    IArenaCreditsDispatcher { contract_address }.consume_credits(user, credits);
}


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
    use super::{ArenaCredit, Energy, IArenaCredits};

    component!(path: access_component, storage: access, event: AccessEvents);

    const ARENA_CREDIT_TABLE_ID: felt252 = bytearrays_hash!("arcade", "ArenaCredit");
    impl ArenaCreditTable = ToriiTable<ARENA_CREDIT_TABLE_ID>;


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
