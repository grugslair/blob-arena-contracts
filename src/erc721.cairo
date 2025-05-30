use core::poseidon::poseidon_hash_span;
use starknet::ContractAddress;
use openzeppelin_token::erc721::{ERC721Component};
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


trait ERC721Internal<TState> {
    // IERC721Metadata
    fn name(self: @TState) -> ByteArray;
    fn symbol(self: @TState) -> ByteArray;
    fn token_uri(self: @TState, token_id: u256) -> ByteArray;

    fn balance_of(self: @TState, account: ContractAddress) -> u256;
    fn owner_of(self: @TState, token_id: u256) -> ContractAddress;
    fn safe_transfer_from(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>,
    );
    fn transfer_from(ref self: TState, from: ContractAddress, to: ContractAddress, token_id: u256);
    fn approve(ref self: TState, to: ContractAddress, token_id: u256);
    fn set_approval_for_all(ref self: TState, operator: ContractAddress, approved: bool);
    fn get_approved(self: @TState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(
        self: @TState, owner: ContractAddress, operator: ContractAddress,
    ) -> bool;
}


#[starknet::embeddable]
impl IERC721Abi<
    TContractState, impl ERC721: ERC721Internal<TContractState>,
> of ERC721ABI<TContractState> {
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256 {
        ERC721::balance_of(self, account)
    }
    fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress {
        ERC721::owner_of(self, token_id)
    }
    fn safe_transfer_from(
        ref self: TContractState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>,
    ) {
        ERC721::safe_transfer_from(ref self, from, to, token_id, data);
    }
    fn transfer_from(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, token_id: u256,
    ) {
        ERC721::transfer_from(ref self, from, to, token_id);
    }
    fn approve(ref self: TContractState, to: ContractAddress, token_id: u256) {
        ERC721::approve(ref self, to, token_id);
    }
    fn set_approval_for_all(ref self: TContractState, operator: ContractAddress, approved: bool) {
        ERC721::set_approval_for_all(ref self, operator, approved);
    }
    fn get_approved(self: @TContractState, token_id: u256) -> ContractAddress {
        ERC721::get_approved(self, token_id)
    }
    fn is_approved_for_all(
        self: @TContractState, owner: ContractAddress, operator: ContractAddress,
    ) -> bool {
        ERC721::is_approved_for_all(self, owner, operator)
    }

    // IERC721Metadata
    fn name(self: @TContractState) -> ByteArray {
        ERC721::name(self)
    }
    fn symbol(self: @TContractState) -> ByteArray {
        ERC721::symbol(self)
    }
    fn token_uri(self: @TContractState, token_id: u256) -> ByteArray {
        ERC721::token_uri(self, token_id)
    }

    // IERC721CamelOnly
    fn balanceOf(self: @TContractState, account: ContractAddress) -> u256 {
        ERC721::balance_of(self, account)
    }
    fn ownerOf(self: @TContractState, tokenId: u256) -> ContractAddress {
        ERC721::owner_of(self, tokenId)
    }
    fn safeTransferFrom(
        ref self: TContractState,
        from: ContractAddress,
        to: ContractAddress,
        tokenId: u256,
        data: Span<felt252>,
    ) {
        ERC721::safe_transfer_from(ref self, from, to, tokenId, data);
    }

    fn transferFrom(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, tokenId: u256,
    ) {
        ERC721::transfer_from(ref self, from, to, tokenId);
    }
    fn setApprovalForAll(ref self: TContractState, operator: ContractAddress, approved: bool) {
        ERC721::set_approval_for_all(ref self, operator, approved);
    }
    fn getApproved(self: @TContractState, tokenId: u256) -> ContractAddress {
        ERC721::get_approved(self, tokenId)
    }
    fn isApprovedForAll(
        self: @TContractState, owner: ContractAddress, operator: ContractAddress,
    ) -> bool {
        ERC721::is_approved_for_all(self, owner, operator)
    }

    // IERC721MetadataCamelOnly
    fn tokenURI(self: @TContractState, tokenId: u256) -> ByteArray {
        ERC721::token_uri(self, tokenId)
    }
}

