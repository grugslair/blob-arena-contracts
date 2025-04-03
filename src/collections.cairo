use starknet::ContractAddress;

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
