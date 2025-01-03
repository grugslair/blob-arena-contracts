use starknet::ContractAddress;
use dojo::{world::WorldStorage, model::{ModelStorage, Model, ModelValueStorage}};
use blob_arena::collections::blobert::{Seed, TokenAttributes};

#[dojo::model]
#[derive(Drop, Serde, Copy)]
struct BlobertToken {
    #[key]
    id: felt252,
    owner: ContractAddress,
    attributes: TokenAttributes,
}

#[dojo::model]
#[derive(Drop, Serde, Copy)]
struct LastMint {
    #[key]
    player: ContractAddress,
    timestamp: u64,
}

#[generate_trait]
impl ArcadeBlobertImpl of ArcadeBlobertStorage {
    fn set_blobert_token(
        ref self: WorldStorage, id: felt252, owner: ContractAddress, attributes: TokenAttributes
    ) {
        self.write_model(@BlobertToken { id, owner, attributes });
    }

    fn get_blobert_token<T, +TryInto<T, felt252>>(
        self: @WorldStorage, token_id: T
    ) -> BlobertToken {
        let token_id: felt252 = token_id.try_into().unwrap();
        self.read_model(token_id)
    }
    fn get_blobert_token_owner(self: @WorldStorage, token_id: u256) -> ContractAddress {
        let token_id: felt252 = token_id.try_into().unwrap();
        self.read_member(Model::<BlobertToken>::ptr_from_keys(token_id), selector!("owner"))
    }

    fn get_blobert_token_attributes(self: @WorldStorage, token_id: u256) -> TokenAttributes {
        let token_id: felt252 = token_id.try_into().unwrap();
        self.read_member(Model::<BlobertToken>::ptr_from_keys(token_id), selector!("attributes"))
    }

    fn get_last_mint(self: @WorldStorage, caller: ContractAddress) -> u64 {
        self.read_member(Model::<LastMint>::ptr_from_keys(caller), selector!("timestamp"))
    }
    fn set_last_mint(ref self: WorldStorage, player: ContractAddress, timestamp: u64) {
        self.write_model(@LastMint { player, timestamp });
    }
}
