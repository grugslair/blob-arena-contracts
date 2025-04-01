use starknet::ContractAddress;
use dojo::{world::WorldStorage, model::{ModelStorage, Model, ModelValueStorage}};

/// Represents the last minting action for a player
///
/// # Fields
///
/// * `player` - The contract address of the player who minted, used as key
/// * `timestamp` - timestamp in seconds of when the last mint occurred
#[dojo::model]
#[derive(Drop, Serde)]
struct LastMint {
    #[key]
    player: ContractAddress,
    timestamp: u64,
}

/// Represents the number of tokens owned by a player
///
/// # Fields
///
/// * `player` - The address of the player who owns the tokens
/// * `amount` - The number of tokens owned by the player
#[dojo::model]
#[derive(Drop, Serde)]
struct AmountTokensOwned {
    #[key]
    player: ContractAddress,
    amount: u64,
}

#[generate_trait]
impl FreeBlobertStorageImpl of FreeBlobertStorage {
    fn get_last_mint(self: @WorldStorage, caller: ContractAddress) -> u64 {
        self.read_member(Model::<LastMint>::ptr_from_keys(caller), selector!("timestamp"))
    }
    fn set_last_mint(ref self: WorldStorage, player: ContractAddress, timestamp: u64) {
        self.write_model(@LastMint { player, timestamp });
    }
    fn set_amount_tokens_owned(ref self: WorldStorage, player: ContractAddress, amount: u64) {
        self.write_model(@AmountTokensOwned { player, amount });
    }
    fn get_amount_tokens_owned(self: @WorldStorage, player: ContractAddress) -> u64 {
        self.read_member(Model::<AmountTokensOwned>::ptr_from_keys(player), selector!("amount"))
    }
}
