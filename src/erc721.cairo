use starknet::ContractAddress;
use openzeppelin_token::erc721::{ERC721ABIDispatcher, ERC721ABIDispatcherTrait};


fn erc721_owner_of(contract_address: ContractAddress, token_id: u256) -> ContractAddress {
    ERC721ABIDispatcher { contract_address }.owner_of(token_id)
}
