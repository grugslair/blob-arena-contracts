#[starknet::interface]
pub trait IERC721Metadata<TContractState> {
    /// Returns the name of the token collection
    fn name(self: @TContractState) -> ByteArray;
    /// Returns the symbol of the token collection
    fn symbol(self: @TContractState) -> ByteArray;
    /// Returns the URI for a specific token ID
    fn token_uri(self: @TContractState, token_id: u256) -> ByteArray;
    fn tokenURI(self: @TContractState, tokenId: u256) -> ByteArray;
}

pub mod metadata_impl {
    #[starknet::embeddable]
    pub impl IERC721MetadataImpl<
        TContractState, impl MetadataInfo: super::ERC721MetadataInfo,
    > of super::IERC721Metadata<TContractState> {
        fn name(self: @TContractState) -> ByteArray {
            MetadataInfo::name()
        }

        fn symbol(self: @TContractState) -> ByteArray {
            MetadataInfo::symbol()
        }

        fn token_uri(self: @TContractState, token_id: u256) -> ByteArray {
            format!("{}/{}", MetadataInfo::base_token_uri(), token_id).into()
        }
        fn tokenURI(self: @TContractState, tokenId: u256) -> ByteArray {
            Self::token_uri(self, tokenId)
        }
    }
}

pub trait ERC721MetadataInfo {
    /// Returns the name of the token collection
    fn name() -> ByteArray;
    /// Returns the symbol of the token collection
    fn symbol() -> ByteArray;
    /// Returns the URI for a specific token ID
    fn base_token_uri() -> ByteArray;
}

