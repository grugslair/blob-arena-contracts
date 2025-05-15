use core::{num::traits::One, poseidon::poseidon_hash_span};
use starknet::{
    get_caller_address, ContractAddress, get_contract_address, StorageAddress,
    storage_access::{storage_base_address_const, storage_address_from_base, storage_read_syscall},
    SyscallResultTrait,
};
use dojo::{
    world::{
        WorldStorage, IWorldDispatcher, WorldStorageTrait, IWorldDispatcherTrait,
        storage::ModelStorageWorldStorageImpl,
    },
    model::{Model, ModelIndex, ModelStorage, ModelPtr},
    contract::{IContractDispatcherTrait, IContractDispatcher},
    utils::{deserialize_unwrap, entity_id_from_keys}, meta::{Introspect, Layout, FieldLayout},
};
use dojo::contract::components::world_provider::world_provider_cpt::{
    WorldProvider, HasComponent as WorldComponent,
};

use blob_arena::{utils::{storage_read, storage_write, get_transaction_hash}, hash::hash_value};
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

fn pseudo_randomness() -> felt252 {
    poseidon_hash_span([incrementor(selector!("randomness")), get_transaction_hash()].span())
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
impl ModelsImpl of ModelsTrait {
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
    fn storage(self: @T, namespace_hash: felt252) -> WorldStorage;
    fn default_storage(self: @T) -> WorldStorage {
        Self::storage(self, DEFAULT_NAMESPACE_HASH)
    }
}

#[generate_trait]
impl WorldModelImpl<S, M, +WorldTrait<S>, +Drop<S>, +Model<M>, +Drop<M>> of NsModelStorage<S, M> {
    fn write_ns_model(ref self: S, namespace: felt252, model: @M) {
        let mut storage = self.storage(namespace);
        ModelStorageWorldStorageImpl::<M>::write_model(ref storage, model);
    }
    fn write_ns_models(ref self: S, namespace: felt252, models: Span<@M>) {
        let mut storage = self.storage(namespace);
        ModelStorageWorldStorageImpl::<M>::write_models(ref storage, models);
    }
    fn read_ns_model<K, +Drop<K>, +Serde<K>>(self: @S, namespace: felt252, keys: K) -> M {
        ModelStorageWorldStorageImpl::<M>::read_model(@self.storage(namespace), keys)
    }
    fn read_ns_models<K, +Drop<K>, +Serde<K>>(
        self: @S, namespace: felt252, keys: Span<K>,
    ) -> Array<M> {
        ModelStorageWorldStorageImpl::<M>::read_models(@self.storage(namespace), keys)
    }
    fn erase_ns_model(ref self: S, namespace: felt252, model: @M) {
        let mut storage = self.storage(namespace);
        ModelStorageWorldStorageImpl::<M>::erase_model(ref storage, model);
    }
    fn erase_ns_models(ref self: S, namespace: felt252, models: Span<@M>) {
        let mut storage = self.storage(namespace);
        ModelStorageWorldStorageImpl::<M>::erase_models(ref storage, models);
    }
    fn erase_ns_model_ptr(ref self: S, namespace: felt252, ptr: ModelPtr<M>) {
        let mut storage = self.storage(namespace);
        ModelStorageWorldStorageImpl::<M>::erase_model_ptr(ref storage, ptr);
    }
    fn erase_ns_models_ptrs(ref self: S, namespace: felt252, ptrs: Span<ModelPtr<M>>) {
        let mut storage = self.storage(namespace);
        ModelStorageWorldStorageImpl::<M>::erase_models_ptrs(ref storage, ptrs);
    }
    fn read_ns_member<T, +Serde<T>>(
        self: @S, namespace: felt252, ptr: ModelPtr<M>, field_selector: felt252,
    ) -> T {
        ModelStorageWorldStorageImpl::<
            M,
        >::read_member(@self.storage(namespace), ptr, field_selector)
    }
    fn read_ns_member_of_models<T, +Serde<T>, +Drop<T>>(
        self: @S, namespace: felt252, ptrs: Span<ModelPtr<M>>, field_selector: felt252,
    ) -> Array<T> {
        ModelStorageWorldStorageImpl::<
            M,
        >::read_member_of_models(@self.storage(namespace), ptrs, field_selector)
    }
    fn write_ns_member<T, +Serde<T>, +Drop<T>>(
        ref self: S, namespace: felt252, ptr: ModelPtr<M>, field_selector: felt252, value: T,
    ) {
        let mut storage = self.storage(namespace);
        ModelStorageWorldStorageImpl::<M>::write_member(ref storage, ptr, field_selector, value);
    }
    fn write_ns_member_of_models<T, +Serde<T>, +Drop<T>>(
        ref self: S,
        namespace: felt252,
        ptrs: Span<ModelPtr<M>>,
        field_selector: felt252,
        values: Span<T>,
    ) {
        let mut storage = self.storage(namespace);
        ModelStorageWorldStorageImpl::<
            M,
        >::write_member_of_models(ref storage, ptrs, field_selector, values);
    }
    fn read_ns_schema<T, +Serde<T>, +Introspect<T>>(
        self: @S, namespace: felt252, ptr: ModelPtr<M>,
    ) -> T {
        ModelStorageWorldStorageImpl::<M>::read_schema(@self.storage(namespace), ptr)
    }
    fn read_ns_schemas<T, +Drop<T>, +Serde<T>, +Introspect<T>>(
        self: @S, namespace: felt252, ptrs: Span<ModelPtr<M>>,
    ) -> Array<T> {
        ModelStorageWorldStorageImpl::<M>::read_schemas(@self.storage(namespace), ptrs)
    }
}

impl IWorldDispatcherWorldImpl of WorldTrait<IWorldDispatcher> {
    fn storage(self: @IWorldDispatcher, namespace_hash: felt252) -> WorldStorage {
        WorldStorageTrait::new_from_hash(*self, namespace_hash)
    }
}

impl WorldStorageWorldImpl of WorldTrait<WorldStorage> {
    fn storage(self: @WorldStorage, namespace_hash: felt252) -> WorldStorage {
        WorldStorageTrait::new_from_hash(*self.dispatcher, namespace_hash)
    }
}

impl ContractStateWorldImpl<TState, +Drop<TState>, +WorldComponent<TState>> of WorldTrait<TState> {
    fn storage(self: @TState, namespace_hash: felt252) -> WorldStorage {
        WorldStorageTrait::new_from_hash(self.get_component().world_dispatcher(), namespace_hash)
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

