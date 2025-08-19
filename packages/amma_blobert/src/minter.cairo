use starknet::ContractAddress;

#[starknet::interface]
trait IAmmaBlobertMinter<TState> {
    fn claimed(self: @TState, user: ContractAddress) -> bool;
    fn claim(ref self: TState) -> Array<u256>;
}


#[starknet::contract]
mod amma_blobert_minter {
    use sai_return::emit_return;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address};
    use crate::mint_fighter;
    use super::IAmmaBlobertMinter;

    #[storage]
    struct Storage {
        contract_address: ContractAddress,
        claimed: Map<ContractAddress, bool>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, contract_address: ContractAddress) {
        self.contract_address.write(contract_address);
    }


    #[abi(embed_v0)]
    impl IAmmaBlobertMinterImpl of IAmmaBlobertMinter<ContractState> {
        fn claimed(self: @ContractState, user: ContractAddress) -> bool {
            self.claimed.read(user)
        }

        fn claim(ref self: ContractState) -> Array<u256> {
            let caller = get_caller_address();
            assert(!self.claimed.read(caller), 'Already Claimed');
            self.claimed.write(caller, true);
            let contract_address = self.contract_address.read();
            emit_return(
                array![
                    mint_fighter(contract_address, caller, 1),
                    mint_fighter(contract_address, caller, 2),
                ],
            )
        }
    }
}
