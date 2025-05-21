#[starknet::component]
mod address_book_cpt {
    #[storage]
    struct Storage {
        addresses: Map<felt252, ContractAddress>,
    }

    #[generate_trait]
    impl AddressBookInternalImpl of AddressBookInternal {
        fn set_address(ref self: @Storage, selector: felt252, address: ContractAddress) {
            self.addresses.write(selector, address);
        }

        fn address(self: @Storage, selector: felt252) -> ContractAddress {
            self.addresses.read(selector)
        }
    }
}
