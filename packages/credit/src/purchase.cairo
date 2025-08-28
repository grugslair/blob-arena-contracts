use starknet::ContractAddress;

#[starknet::interface]
trait IArcadeCreditPurchase<TState> {
    // Gets the price of game tokens in micro USD
    /// # Arguments
    /// * `amount` - The number of game tokens to get the price for
    /// # Returns
    /// * `u128` - The price of a single game token in micro USD
    fn get_micro_usd_price(self: @TState, amount: u128) -> u128;

    /// Gets the price of game tokens in the current contract
    /// # Arguments
    /// * `erc20_address` - The contract address of the ERC20 token used for payments
    /// * `amount` - The number of game tokens to get the price for
    /// # Returns
    /// * `u256` - The price of the specified amount of game tokens
    fn get_price(self: @TState, erc20_address: ContractAddress, amount: u128) -> u256;

    /// Purchases game tokens for the caller
    /// # Arguments
    /// * `erc20_address` - The contract address of the ERC20 token used for payments
    /// * `receiver` - The contract address of the receiver 0x0 for the caller
    /// * `amount` - The number of game tokens to purchase
    fn purchase(
        ref self: TState, erc20_address: ContractAddress, receiver: ContractAddress, amount: u128,
    );

    /// Gets the current contract address for the Pragma ABI dispatcher
    /// # Arguments
    /// * `contract_address` - The address of the Pragma ABI dispatcher contract``
    fn set_pragma_contract_address(ref self: TState, contract_address: ContractAddress);

    /// Sets the price pair for a specific ERC20 token
    /// # Arguments
    /// * `erc20_address` - The contract address of the ERC20 token
    /// * `price_pair` - The price pair identifier for the token ('LORDS/USD')
    fn set_price_pair(ref self: TState, erc20_address: ContractAddress, price_pair: felt252);
    /// Sets the price of game tokens in micro USD
    /// # Arguments
    /// * `price` - The price of a single game token in micro USD
    fn set_micro_usd_price(ref self: TState, price: u128);
    /// Set wallet address for payments
    /// # Arguments
    /// * `wallet_address` - The contract address of the wallet to receive payments
    fn set_wallet_address(ref self: TState, wallet_address: ContractAddress);
}


#[starknet::contract]
mod arena_credit_purchase {
    use core::num::traits::{Pow, Zero};
    use openzeppelin_token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use pragma_lib::abi::{
        DataType, IPragmaABIDispatcher, IPragmaABIDispatcherTrait, PragmaPricesResponse,
    };
    use sai_ownable::{OwnableTrait, ownable_component};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address};
    use crate::arena_credit_add_credits;
    use super::IArcadeCreditPurchase;

    component!(path: ownable_component, storage: ownable, event: OwnableEvents);


    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: ownable_component::Storage,
        pragma_dispatcher: IPragmaABIDispatcher,
        wallet_address: ContractAddress,
        token_micro_usd_price: u128,
        price_pairs: Map<ContractAddress, felt252>,
        credit_address: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvents: ownable_component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, owner: ContractAddress, credit_address: ContractAddress,
    ) {
        self.credit_address.write(credit_address);
        self.grant_owner(owner);
    }

    #[abi(embed_v0)]
    impl IOwnableImpl = ownable_component::OwnableImpl<ContractState>;

    #[abi(embed_v0)]
    impl IArcadeCreditPurchaseImpl of IArcadeCreditPurchase<ContractState> {
        fn get_micro_usd_price(self: @ContractState, amount: u128) -> u128 {
            let price = self.token_micro_usd_price.read();
            assert(price > 0, 'Token price not set');
            amount.into() * price
        }

        fn get_price(self: @ContractState, erc20_address: ContractAddress, amount: u128) -> u256 {
            self.get_tokens_price(erc20_address, amount)
        }

        fn purchase(
            ref self: ContractState,
            erc20_address: ContractAddress,
            mut receiver: ContractAddress,
            amount: u128,
        ) {
            let caller = get_caller_address();
            if receiver.is_zero() {
                receiver = caller;
            }
            let price = self.get_tokens_price(erc20_address, amount);
            ERC20ABIDispatcher { contract_address: erc20_address }
                .transfer_from(caller, self.wallet_address.read(), price);
            arena_credit_add_credits(self.credit_address.read(), receiver, amount);
        }

        fn set_pragma_contract_address(ref self: ContractState, contract_address: ContractAddress) {
            self.assert_caller_is_owner();
            self.pragma_dispatcher.write(IPragmaABIDispatcher { contract_address });
        }

        fn set_price_pair(
            ref self: ContractState, erc20_address: ContractAddress, price_pair: felt252,
        ) {
            self.assert_caller_is_owner();
            self.price_pairs.write(erc20_address, price_pair);
        }

        fn set_micro_usd_price(ref self: ContractState, price: u128) {
            self.assert_caller_is_owner();
            self.token_micro_usd_price.write(price);
        }

        fn set_wallet_address(ref self: ContractState, wallet_address: ContractAddress) {
            self.assert_caller_is_owner();
            self.wallet_address.write(wallet_address);
        }
    }

    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn get_tokens_price(
            self: @ContractState, erc20_address: ContractAddress, amount: u128,
        ) -> u256 {
            let price_pair = self.price_pairs.read(erc20_address);
            assert(price_pair.is_non_zero(), 'ERC20 not accepted');
            let PragmaPricesResponse {
                price,
                decimals,
                last_updated_timestamp: _,
                num_sources_aggregated: _,
                expiration_timestamp: _,
            } = self.pragma_dispatcher.read().get_data_median(DataType::SpotEntry(price_pair));

            (self.token_micro_usd_price.read().into()
                * amount.into()
                * 10_u256.pow(decimals.into())
                * 1_000_000_000_000_000_000
                / (price.into() * 1_000_000))
                .into()
        }
    }
}
