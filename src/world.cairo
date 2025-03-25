use core::{num::traits::One, poseidon::poseidon_hash_span};
use starknet::{
    get_caller_address, ContractAddress, get_contract_address, StorageAddress,
    storage_access::{storage_base_address_const, storage_address_from_base, storage_read_syscall},
    SyscallResultTrait,
};
use dojo::{
    world::{WorldStorage, IWorldDispatcher, WorldStorageTrait, IWorldDispatcherTrait},
    model::{Model, ModelIndex, ModelStorage},
    contract::{
        IContractDispatcherTrait, IContractDispatcher,
        components::world_provider::world_provider_cpt::{
            WorldProvider, HasComponent as WorldComponent,
        },
    },
    utils::{deserialize_unwrap, entity_id_from_keys}, meta::{Introspect, Layout, FieldLayout},
};

use blob_arena::{utils::{storage_read, storage_write}, hash::hash_value};
const DEFAULT_NAMESPACE_HASH: felt252 = bytearray_hash!("blob_arena");

fn uuid() -> felt252 {
    let storage_address: StorageAddress = 'uuid'.try_into().unwrap();
    let value = storage_read(storage_address) + 1;
    storage_write(storage_address, value);
    poseidon_hash_span([get_contract_address().into(), value].span())
}

fn incrementor(key: felt252) -> felt252 {
    let storage_address: StorageAddress = key.try_into().unwrap();
    let value = storage_read(storage_address) + 1;
    storage_write(storage_address, value);
    value
}

const WORLD_STORAGE_LOCATION: felt252 =
    0x01704e5494cfadd87ce405d38a662ae6a1d354612ea0ebdc9fefdeb969065774;


fn get_world_address() -> ContractAddress {
    storage_read_syscall(
        0, storage_address_from_base(storage_base_address_const::<WORLD_STORAGE_LOCATION>()),
    )
        .unwrap_syscall()
        .try_into()
        .unwrap()
}

fn get_storage_from_hash(namespace_hash: felt252) -> WorldStorage {
    WorldStorage {
        dispatcher: IWorldDispatcher { contract_address: get_world_address() }, namespace_hash,
    }
}

fn get_default_storage() -> WorldStorage {
    get_storage_from_hash(DEFAULT_NAMESPACE_HASH)
}

#[generate_trait]
impl ModelImpl of ModelTrait {
    fn write_models_check<M, +Model<M>, +Drop<M>>(ref self: WorldStorage, models: Span<@M>) {
        let len = models.len();
        if len.is_one() {
            self.write_model(*models.at(0));
        } else if len > 0 {
            self.write_models(models);
        }
    }
}

trait WorldTrait<T> {
    fn new_storage(self: @T, namespace_hash: felt252) -> WorldStorage;
    fn new_default_storage(
        self: @T,
    ) -> WorldStorage {
        Self::new_storage(self, DEFAULT_NAMESPACE_HASH)
    }
}

impl IWorldDispatcherWorldImpl of WorldTrait<IWorldDispatcher> {
    fn new_storage(self: @IWorldDispatcher, namespace_hash: felt252) -> WorldStorage {
        WorldStorageTrait::new_from_hash(*self, namespace_hash)
    }
}

impl WorldStorageWorldImpl of WorldTrait<WorldStorage> {
    fn new_storage(self: @WorldStorage, namespace_hash: felt252) -> WorldStorage {
        WorldStorageTrait::new_from_hash(*self.dispatcher, namespace_hash)
    }
}

#[generate_trait]
impl WorldDispatcherImpl<
    TContractState, +WorldComponent<TContractState>,
> of WorldDispatcher<TContractState> {
    fn world_dispatcher(self: @TContractState) -> IWorldDispatcher {
        self.get_component().world_dispatcher()
    }
}

// #[generate_trait]
// impl WorldStorageImpl of LayoutStorage {
//     fn read_nested_member<M, L, T, K, +Model<M>, +Introspect<L>, +Serde<T>, +Serde<K>>(
//         self: @WorldStorage, keys: @K, selectors: Span<felt252>,
//     ) -> T {
//         let (mut entity_id, mut member_id) = (entity_id_from_keys(keys), *selectors.at(0));
//         for n in 1..(selectors.len()) {
//             entity_id = dojo::utils::combine_key(entity_id, member_id);
//             member_id = *selectors.at(n);
//         };

//         deserialize_unwrap(
//             IWorldDispatcherTrait::entity(
//                 *self.dispatcher,
//                 Model::<M>::selector(*self.namespace_hash),
//                 ModelIndex::MemberId((entity_id, member_id)),
//                 Introspect::<L>::layout(),
//             ),
//         )
//     }
//     fn read_member_from_layout<M, L, T, K, +Model<M>, +Introspect<L>, +Serde<T>, +Serde<K>>(
//         self: @WorldStorage, keys: @K, selector: felt252,
//     ) {
//         deserialize_unwrap(
//             IWorldDispatcherTrait::entity(
//                 *self.dispatcher,
//                 Model::<M>::selector(*self.namespace_hash),
//                 ModelIndex::MemberId((entity_id_from_keys(keys), selector)),
//                 Introspect::<L>::layout(),
//             ),
//         )
//     }
// }

fn default_namespace() -> @ByteArray {
    @"blob_arena"
}


pub trait DefaultStorage<TContractState> {
    fn default_storage(self: @TContractState) -> WorldStorage;
}

