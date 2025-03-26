use starknet::ContractAddress;
use dojo::{world::WorldStorage, model::{ModelStorage, Model, ModelValueStorage}};
use blob_arena::collections::blobert::{Seed, TokenAttributes};

/// Game models

/// A struct representing a Blobert NFT token in the game.
///
/// # Fields
/// * `id` - Unique identifier for the Blobert token, used as a key
/// * `owner` - COntract address of the token owner
/// * `attributes` - Collection of token attributes
///
/// This model is used to store token ownership and attribute data for Bloberts in the game.
/// It is decorated with Dojo model and implements Drop and Serde traits.
#[dojo::model]
#[derive(Drop, Serde)]
struct BlobertToken {
    #[key]
    id: felt252,
    owner: ContractAddress,
    attributes: TokenAttributes,
}

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

#[dojo::model]
#[derive(Drop, Serde)]
struct AmountTokensOwned {
    #[key]
    player: ContractAddress,
    amount: u64,
}

#[generate_trait]
impl ArcadeBlobertStorageImpl of ArcadeBlobertStorage {
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
