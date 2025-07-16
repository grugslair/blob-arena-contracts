pub mod erc721 {
    pub mod metadata;
    pub use metadata::{
        ERC721MetadataInfo, IERC721Metadata, IERC721MetadataDispatcher,
        IERC721MetadataDispatcherTrait, metadata_impl,
    };
    pub mod soulbound;
}
