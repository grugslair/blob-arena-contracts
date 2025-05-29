use core::poseidon::poseidon_hash_span;
use starknet::ContractAddress;
use openzeppelin_token::erc721::{ERC721ABIDispatcher, ERC721ABIDispatcherTrait};
use dojo::{world::WorldStorage, model::{Model, ModelStorage}};
use crate::world::WorldTrait;


fn erc721_owner_of(contract_address: ContractAddress, token_id: u256) -> ContractAddress {
    ERC721ABIDispatcher { contract_address }.owner_of(token_id)
}


const ERC721_NAMESPACE_HASH: felt252 = bytearray_hash!("erc721_tokens");

#[derive(Drop, Copy, Serde, Introspect)]
struct ERC721Token {
    collection_address: ContractAddress,
    token_id: u256,
}

fn erc721_token_key(collection_address: ContractAddress, token_id: u256) -> felt252 {
    poseidon_hash_span(
        [collection_address.into(), token_id.high.into(), token_id.low.into()].span(),
    )
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
    fn erc721_token_storage(self: @WorldStorage) -> WorldStorage {
        self.storage(ERC721_NAMESPACE_HASH)
    }

    fn get_erc721_token(self: WorldStorage, key: felt252) -> ERC721Token {
        self.erc721_token_storage().read_schema(Model::<model::ERC721Token>::ptr_from_keys(key))
    }

    fn set_erc721_token(
        ref self: WorldStorage, collection_address: ContractAddress, token_id: u256,
    ) -> felt252 {
        let key = poseidon_hash_span(
            [collection_address.into(), token_id.low.into(), token_id.high.into()].span(),
        );
        let mut storage = self.erc721_token_storage();
        storage.write_model(@model::ERC721Token { key, collection_address, token_id });
        key
    }
}
