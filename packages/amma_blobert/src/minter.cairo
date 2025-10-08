use starknet::ContractAddress;

/// Interface for the Amma Blobert NFT minting contract
///
/// Provides functionality for users to claim their free Amma Blobert NFTs.
/// Each user can only claim once, receiving two NFTs (indexes 1 and 2).
#[starknet::interface]
trait IAmmaBlobertMinter<TState> {
    /// Checks if a user has already claimed their free Amma Blobert NFTs
    ///
    /// # Arguments
    /// * `user` - The wallet address to check claim status for
    ///
    /// # Returns
    /// * `bool` - True if the user has already claimed, false otherwise
    fn claimed(self: @TState, user: ContractAddress) -> bool;

    /// Claims free Amma Blobert NFTs for the caller
    ///
    /// Mints two Amma Blobert NFTs (with indexes 1 and 2) to the caller's address.
    /// Can only be called once per address.
    ///
    /// # Returns
    /// * `Array<u256>` - Array containing the token IDs of the newly minted NFTs
    ///
    /// # Panics
    /// * If the caller has already claimed their NFTs
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
        token_address: ContractAddress,
        claimed: Map<ContractAddress, bool>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, token_address: ContractAddress) {
        self.token_address.write(token_address);
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
            let token_address = self.token_address.read();
            emit_return(
                array![
                    mint_fighter(token_address, caller, 1), mint_fighter(token_address, caller, 2),
                ],
            )
        }
    }
}
