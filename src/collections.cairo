use core::poseidon::poseidon_hash_span;
use starknet::ContractAddress;
use dojo::{world::WorldStorage, model::{Model, ModelStorage}};

mod interface;
mod blobert;
mod arcade_blobert;
mod amma_blobert;


use super::collections::interface::{
    get_collection_dispatcher, ICollection, ICollectionDispatcher, ICollectionDispatcherTrait,
};


#[derive(Drop, Copy, Serde, Introspect)]
struct ERC721Token {
    collection_address: ContractAddress,
    token_id: u256,
}

mod model {
    use starknet::ContractAddress;

    #[dojo::model]
    #[derive(Drop, Serde)]
    struct ERC721Token {
        #[key]
        key: felt252,
        collection_address: ContractAddress,
        token_id: u256,
    }
}

#[generate_trait]
impl ERC721TokenStorageImpl of ERC721TokenStorage {
    fn get_erc721_token(self: WorldStorage, key: felt252) -> ERC721Token {
        self.read_schema(Model::<model::ERC721Token>::ptr_from_keys(key))
    }

    fn set_erc721_token(
        ref self: WorldStorage, collection_address: ContractAddress, token_id: u256,
    ) {
        let key = poseidon_hash_span(
            [collection_address.into(), token_id.low.into(), token_id.high.into()].span(),
        );
        self.write_model(@model::ERC721Token { key, collection_address, token_id });
    }
}

