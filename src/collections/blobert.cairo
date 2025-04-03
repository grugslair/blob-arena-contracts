mod external;
mod storage;
mod components;
mod systems;
mod contract;
mod items;

use components::{TokenAttributes, BlobertAttribute, Seed, BlobertItemKey, AttackSlot, to_seed_key,};
use storage::BlobertStorage;
use systems::BlobertTrait;
use items::IBlobertItems;


fn blobert_namespace() -> @ByteArray {
    @"blobert"
}
