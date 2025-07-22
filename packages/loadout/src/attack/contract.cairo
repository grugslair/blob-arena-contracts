use starknet::ClassHash;

#[starknet::interface]
trait ITest<TContractState> {
    fn test(self: @TContractState, input: i32) -> felt252;
}

#[starknet::contract]
mod attack {
    use sai_access::access_component;
    use sai_core_utils::poseidon_serde::PoseidonSerde;
    use torii_beacon::dojo::const_ns;
    use torii_beacon::dojo::traits::BeaconEmitterTrait;
    use torii_beacon::emitter_component;
    use crate::attack::types::InputIntoEffectArray;
    use crate::attack::{Effect, EffectInput, get_attack_id};


    component!(path: emitter_component, storage: emitter, event: EmitterEvents);
    component!(path: access_component, storage: access, event: AccessEvents);
    const NAMESPACE_HASH: felt252 = 'attack';
    impl Emitter = const_ns::ConstNsBeaconEmitter<NAMESPACE_HASH, ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        emitter: emitter_component::Storage,
        #[substorage(v0)]
        access: access_component::Storage,
        speed: u8,
        accuracy: u8,
        cooldown: u8,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        EmitterEvents: emitter_component::Event,
        #[flat]
        AccessEvents: access_component::Event,
    }

    #[abi(embed_v0)]
    impl ITestImpl of super::ITest<ContractState> {
        fn test(self: @ContractState, input: i32) -> felt252 {
            // Example implementation
            let result = input * 2; // Just a dummy operation
            result.into()
        }
    }

    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn _create_attack(
            ref self: ContractState,
            name: ByteArray,
            speed: u8,
            accuracy: u8,
            cooldown: u8,
            hit: Array<EffectInput>,
            miss: Array<EffectInput>,
        ) -> felt252 {
            let hit: Array<Effect> = hit.into();
            let miss: Array<Effect> = miss.into();
            let id = get_attack_id(@name, speed, accuracy, cooldown, @hit, @miss);

            id
        }
    }
}
// use starknet::ContractAddress;

// #[starknet::interface]
// trait IContractRegistry<TContractState> {
//     fn register(
//         ref self: TContractState, namespace_hash: felt252, contract_address: ContractAddress,
//     );
//     fn lookup(self: @TContractState, namespace_hash: felt252) -> ContractAddress;
//     fn grant_owner(ref self: TContractState, owner: ContractAddress);
//     fn revoke_owner(ref self: TContractState, owner: ContractAddress);
//     fn is_owner(self: @TContractState, owner: ContractAddress) -> bool;
// }

// #[starknet::contract]
// mod contract_registry {
//     use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
//     use starknet::{ContractAddress, get_caller_address};

//     #[storage]
//     struct Storage {
//         contracts: Map<felt252, ContractAddress>,
//         owners: Map<ContractAddress, bool>,
//     }

//     #[abi(embed_v0)]
//     impl IContractRegistryImpl of super::IContractRegistry<ContractState> {
//         fn register(
//             ref self: ContractState, namespace_hash: felt252, contract_address: ContractAddress,
//         ) {
//             self.assert_caller_is_owner();
//             self.contracts.write(namespace_hash, contract_address);
//         }

//         fn lookup(self: @ContractState, namespace_hash: felt252) -> ContractAddress {
//             self.contracts.read(namespace_hash)
//         }

//         fn grant_owner(ref self: ContractState, owner: ContractAddress) {
//             self.assert_caller_is_owner();
//             self.owners.write(owner, true);
//         }

//         fn revoke_owner(ref self: ContractState, owner: ContractAddress) {
//             self.assert_caller_is_owner();
//             self.owners.write(owner, false);
//         }

//         fn is_owner(self: @ContractState, owner: ContractAddress) -> bool {
//             self.owners.read(owner)
//         }
//     }

//     #[generate_trait]
//     impl PrivateImpl of PrivateTrait {
//         fn assert_caller_is_owner(self: @ContractState) {
//             assert(self.owners.read(get_caller_address()), 'Caller is not owner');
//         }
//     }
// }

