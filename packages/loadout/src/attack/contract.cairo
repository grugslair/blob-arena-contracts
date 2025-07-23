use super::{Attack, AttackInput, Effect, EffectInput};


#[starknet::interface]
pub trait IAttacks<TContractState> {
    fn attack(self: @TContractState, id: felt252) -> Attack;
    fn attacks(self: @TContractState, ids: Array<felt252>) -> Array<Attack>;
    fn speed(self: @TContractState, id: felt252) -> u8;
    fn speeds(self: @TContractState, ids: Array<felt252>) -> Array<u8>;
    fn accuracy(self: @TContractState, id: felt252) -> u8;
    fn accuracies(self: @TContractState, ids: Array<felt252>) -> Array<u8>;
    fn cooldown(self: @TContractState, id: felt252) -> u8;
    fn cooldowns(self: @TContractState, ids: Array<felt252>) -> Array<u8>;
    fn hit(self: @TContractState, id: felt252) -> Array<Effect>;
    fn hits(self: @TContractState, ids: Array<felt252>) -> Array<Array<Effect>>;
    fn miss(self: @TContractState, id: felt252) -> Array<Effect>;
    fn misses(self: @TContractState, ids: Array<felt252>) -> Array<Array<Effect>>;
    fn create_attack(
        ref self: TContractState,
        name: ByteArray,
        speed: u8,
        accuracy: u8,
        cooldown: u8,
        hit: Array<EffectInput>,
        miss: Array<EffectInput>,
    ) -> felt252;
    fn create_attacks(ref self: TContractState, attacks: Array<AttackInput>) -> Array<felt252>;
}


#[starknet::contract]
mod attack {
    use sai_access::access_component;
    use sai_core_utils::poseidon_serde::PoseidonSerde;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess, Vec};
    use torii_beacon::emitter::const_entity;
    use torii_beacon::emitter_component;
    use crate::attack::types::{
        EffectArrayStorageMapReadAccess, EffectArrayStorageMapWriteAccess, InputIntoEffectArray,
    };
    use crate::attack::{Attack, AttackInput, Effect, EffectInput, get_attack_id};


    component!(path: emitter_component, storage: emitter, event: EmitterEvents);
    component!(path: access_component, storage: access, event: AccessEvents);

    const TABLE_ID: felt252 = bytearrays_hash!("attack", "Attack");
    impl TokenEmitter = const_entity::ConstEntityEmitter<TABLE_ID, ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        emitter: emitter_component::Storage,
        #[substorage(v0)]
        access: access_component::Storage,
        speeds: Map<felt252, u8>,
        accuracies: Map<felt252, u8>,
        cooldowns: Map<felt252, u8>,
        hits: Map<felt252, Vec<Effect>>,
        misses: Map<felt252, Vec<Effect>>,
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
    impl IAttacksImpl of super::IAttacks<ContractState> {
        fn attack(self: @ContractState, id: felt252) -> Attack {
            Attack {
                speed: self.speeds.read(id),
                accuracy: self.accuracies.read(id),
                cooldown: self.cooldowns.read(id),
                hit: self.hits.read(id),
                miss: self.misses.read(id),
            }
        }

        fn attacks(self: @ContractState, ids: Array<felt252>) -> Array<Attack> {
            ids.into_iter().map(|id| self.attack(id)).collect()
        }

        fn speed(self: @ContractState, id: felt252) -> u8 {
            self.speeds.read(id)
        }

        fn speeds(self: @ContractState, ids: Array<felt252>) -> Array<u8> {
            ids.into_iter().map(|id| self.speed(id)).collect()
        }

        fn accuracy(self: @ContractState, id: felt252) -> u8 {
            self.accuracies.read(id)
        }

        fn accuracies(self: @ContractState, ids: Array<felt252>) -> Array<u8> {
            ids.into_iter().map(|id| self.accuracy(id)).collect()
        }

        fn cooldown(self: @ContractState, id: felt252) -> u8 {
            self.cooldowns.read(id)
        }

        fn cooldowns(self: @ContractState, ids: Array<felt252>) -> Array<u8> {
            ids.into_iter().map(|id| self.cooldown(id)).collect()
        }

        fn hit(self: @ContractState, id: felt252) -> Array<Effect> {
            self.hits.read(id).into()
        }

        fn hits(self: @ContractState, ids: Array<felt252>) -> Array<Array<Effect>> {
            ids.into_iter().map(|id| self.hit(id)).collect()
        }

        fn miss(self: @ContractState, id: felt252) -> Array<Effect> {
            self.misses.read(id).into()
        }

        fn misses(self: @ContractState, ids: Array<felt252>) -> Array<Array<Effect>> {
            ids.into_iter().map(|id| self.miss(id)).collect()
        }

        fn create_attack(
            ref self: ContractState,
            name: ByteArray,
            speed: u8,
            accuracy: u8,
            cooldown: u8,
            hit: Array<EffectInput>,
            miss: Array<EffectInput>,
        ) -> felt252 {
            self._create_attack(name, speed, accuracy, cooldown, hit, miss)
        }

        fn create_attacks(ref self: ContractState, attacks: Array<AttackInput>) -> Array<felt252> {
            let mut attack_ids: Array<felt252> = Default::default();
            for attack in attacks {
                attack_ids
                    .append(
                        self
                            ._create_attack(
                                attack.name,
                                attack.speed,
                                attack.accuracy,
                                attack.cooldown,
                                attack.hit,
                                attack.miss,
                            ),
                    )
            }
            attack_ids
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
            self.speeds.write(id, speed);
            self.accuracies.write(id, accuracy);
            self.cooldowns.write(id, cooldown);
            self.hits.write(id, hit);
            self.misses.write(id, miss);
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


