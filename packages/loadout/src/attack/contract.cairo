#[starknet::contract]
mod attack {
    use ba_utils::storage::ShortArrayStore;
    use beacon_library::{ToriiTable, register_table};
    use core::num::traits::Zero;
    use sai_access::{AccessTrait, access_component};
    use sai_core_utils::poseidon_serde::PoseidonSerde;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::storage_access::StorePacking;
    use starknet::{ClassHash, ContractAddress};
    use crate::attack::attack::{
        EffectArrayStorageMapReadAccess, EffectArrayStorageMapWriteAccess, byte_array_to_tag,
    };
    use crate::attack::effect::EffectArrayStorePacking;
    use crate::attack::{
        Attack, AttackWithName, AttackWithNameTrait, Effect, IAttack, IAttackAdmin, IdTagAttack,
    };

    component!(path: access_component, storage: access, event: AccessEvents);

    const ATTACK_TABLE_ID: felt252 = bytearrays_hash!("attack", "Attack");
    impl AttackTable = ToriiTable<ATTACK_TABLE_ID>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        access: access_component::Storage,
        speeds: Map<felt252, u16>,
        chances: Map<felt252, u8>,
        cooldowns: Map<felt252, u32>,
        successes: Map<felt252, Array<felt252>>,
        fails: Map<felt252, Array<felt252>>,
        tags: Map<felt252, felt252>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccessEvents: access_component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, owner: ContractAddress, attack_model_class_hash: ClassHash,
    ) {
        self.grant_owner(owner);
        register_table("attack", "Attack", attack_model_class_hash);
    }

    #[abi(embed_v0)]
    impl IAccessImpl = access_component::AccessImpl<ContractState>;

    #[abi(embed_v0)]
    impl IAttackImpl of IAttack<ContractState> {
        fn attack(self: @ContractState, id: felt252) -> Attack {
            Attack {
                speed: self.speeds.read(id),
                chance: self.chances.read(id),
                cooldown: self.cooldowns.read(id),
                success: self.successes.read(id),
                fail: self.fails.read(id),
            }
        }

        fn attacks(self: @ContractState, ids: Array<felt252>) -> Array<Attack> {
            ids.into_iter().map(|id| self.attack(id)).collect()
        }

        fn speed(self: @ContractState, id: felt252) -> u16 {
            self.speeds.read(id)
        }

        fn speeds(self: @ContractState, ids: Array<felt252>) -> Array<u16> {
            ids.into_iter().map(|id| self.speed(id)).collect()
        }

        fn chance(self: @ContractState, id: felt252) -> u8 {
            self.chances.read(id)
        }

        fn chances(self: @ContractState, ids: Array<felt252>) -> Array<u8> {
            ids.into_iter().map(|id| self.chance(id)).collect()
        }

        fn cooldown(self: @ContractState, id: felt252) -> u32 {
            self.cooldowns.read(id)
        }

        fn cooldowns(self: @ContractState, ids: Array<felt252>) -> Array<u32> {
            ids.into_iter().map(|id| self.cooldown(id)).collect()
        }

        fn success(self: @ContractState, id: felt252) -> Array<Effect> {
            StorePacking::unpack(self.successes.read(id))
        }

        fn successes(self: @ContractState, ids: Array<felt252>) -> Array<Array<Effect>> {
            ids.into_iter().map(|id| self.success(id)).collect()
        }

        fn fail(self: @ContractState, id: felt252) -> Array<Effect> {
            StorePacking::unpack(self.fails.read(id))
        }

        fn fails(self: @ContractState, ids: Array<felt252>) -> Array<Array<Effect>> {
            ids.into_iter().map(|id| self.fail(id)).collect()
        }

        fn attack_id(
            self: @ContractState,
            name: ByteArray,
            speed: u16,
            chance: u8,
            cooldown: u32,
            success: Array<Effect>,
            fail: Array<Effect>,
        ) -> felt252 {
            AttackWithName { name, speed, chance, cooldown, success, fail }.attack_id()
        }

        fn attack_ids(self: @ContractState, attacks: Array<AttackWithName>) -> Array<felt252> {
            attacks.into_iter().map(|attack| attack.attack_id()).collect()
        }

        fn tag(self: @ContractState, tag: felt252) -> felt252 {
            self.tags.read(tag)
        }
    }

    #[abi(embed_v0)]
    impl IAttackAdminImpl of IAttackAdmin<ContractState> {
        fn create_attack(
            ref self: ContractState,
            name: ByteArray,
            speed: u16,
            chance: u8,
            cooldown: u32,
            success: Array<Effect>,
            fail: Array<Effect>,
        ) -> felt252 {
            self.assert_caller_is_writer();
            self._create_attack(AttackWithName { name, speed, chance, cooldown, success, fail })
        }

        fn create_attacks(
            ref self: ContractState, attacks: Array<AttackWithName>,
        ) -> Array<felt252> {
            self.assert_caller_is_writer();
            let mut attack_ids: Array<felt252> = Default::default();
            for attack in attacks {
                attack_ids.append(self._create_attack(attack))
            }
            attack_ids
        }
        fn maybe_create_attacks(
            ref self: ContractState, attacks: Array<IdTagAttack>,
        ) -> Array<felt252> {
            self.assert_caller_is_writer();
            let mut attack_ids: Array<felt252> = Default::default();

            for maybe_attack in attacks {
                let attack_id = match maybe_attack {
                    IdTagAttack::Id(attack_id) => { attack_id },
                    IdTagAttack::Tag(tag) => { self.tags.read(byte_array_to_tag(@tag)) },
                    IdTagAttack::Attack(attack) => { self._create_attack(attack) },
                };
                attack_ids.append(attack_id);
            }
            attack_ids
        }
        fn maybe_create_attacks_array(
            ref self: ContractState, attacks: Array<Array<IdTagAttack>>,
        ) -> Array<Array<felt252>> {
            self.assert_caller_is_writer();
            let mut all_attack_ids: Array<Array<felt252>> = Default::default();
            for attack_array in attacks {
                let mut attack_ids: Array<felt252> = Default::default();
                for maybe_attack in attack_array {
                    let attack_id = match maybe_attack {
                        IdTagAttack::Id(attack_id) => { attack_id },
                        IdTagAttack::Tag(tag) => { self.tags.read(byte_array_to_tag(@tag)) },
                        IdTagAttack::Attack(attack) => { self._create_attack(attack) },
                    };
                    attack_ids.append(attack_id);
                }
                all_attack_ids.append(attack_ids);
            }
            all_attack_ids
        }
    }


    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn _create_attack(ref self: ContractState, attack: AttackWithName) -> felt252 {
            let id = (@attack).attack_id();
            self.tags.write(byte_array_to_tag(@attack.name), id);
            // let attack: Attack = attack.into();
            if self.chances.read(id).is_non_zero() {
                return id; // Attack already exists
            }
            assert(0 < attack.chance && attack.chance <= 100, 'Chance must between 0 and 100');

            AttackTable::set_entity(id, @attack);
            self.speeds.write(id, attack.speed);
            self.chances.write(id, attack.chance);
            self.cooldowns.write(id, attack.cooldown);
            self.successes.write(id, attack.success);
            self.fails.write(id, attack.fail);

            id
        }
    }
}

