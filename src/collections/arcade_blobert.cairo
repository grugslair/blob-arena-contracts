mod storage;
mod systems;
mod contract;
mod collection;

use storage::ArcadeBlobertStorage;
use collection::BlobertCollectionTrait;


const ARCADE_BLOBERT_NAMESPACE_HASH: felt252 = bytearray_hash!("arcade_blobert");
