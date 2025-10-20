use starknet::ContractAddress;

#[starknet::interface]
trait IOrbMinter<TState> {
    fn roll(ref self: TState, to: ContractAddress, chances_permille: [u32; 4]) -> u256;
}

#[starknet::interface]
trait IOrbMinterAdmin<TState> {
    fn set_common_orbs(ref self: TState, orbs: Array<felt252>);
    fn set_rare_orbs(ref self: TState, orbs: Array<felt252>);
    fn set_epic_orbs(ref self: TState, orbs: Array<felt252>);
    fn set_legendary_orbs(ref self: TState, orbs: Array<felt252>);
}

#[starknet::contract]
mod orbs_minter {
    use ba_utils::vrf::{VrfTrait, vrf_component};
    use ba_utils::{SeedProbability, felt252_to_u128};
    use core::num::traits::DivRem;
    use sai_access::{AccessTrait, access_component};
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use crate::{OrbTrait, Rarity};
    use super::IOrbMinter;
    const THOUSAND_NZ: NonZero<u128> = 1000;

    component!(path: vrf_component, storage: vrf, event: VrfEvents);
    component!(path: access_component, storage: access, event: AccessEvents);


    #[storage]
    struct Storage {
        #[substorage(v0)]
        vrf: vrf_component::Storage,
        #[substorage(v0)]
        access: access_component::Storage,
        orb_contract: ContractAddress,
        common_attacks: Map<u32, felt252>,
        rare_attacks: Map<u32, felt252>,
        epic_attacks: Map<u32, felt252>,
        legendary_attacks: Map<u32, felt252>,
        common_attacks_amount: u32,
        rare_attacks_amount: u32,
        epic_attacks_amount: u32,
        legendary_attacks_amount: u32,
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        VrfEvents: vrf_component::Event,
        #[flat]
        AccessEvents: access_component::Event,
    }


    impl IOrbMinterImpl of IOrbMinter<ContractState> {
        fn roll(ref self: ContractState, to: ContractAddress, chances_permille: [u32; 4]) -> u256 {
            self.assert_caller_is_writer();
            let randomness = self.get_nonce_seed(to);
            let (attack_id, rarity) = self.get_random_attack(chances_permille, randomness);
            self.orb_contract.read().mint(to, attack_id, rarity);
        }
    }

    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn get_random_attack(
            self: @ContractState, chances: [u32; 4], randomness: felt252,
        ) -> (felt252, Rarity) {
            let mut seed = felt252_to_u128(randomness);
            let (_seed, value) = seed.div_rem(THOUSAND_NZ);
            seed = _seed;
            let [common, rare, epic, legendary] = chances;
            let mut chance = common;
            if value < chance.into() {
                let number = seed.get_final_value(self.common_attacks_amount.read());
                return (self.common_attacks.read(number), Rarity::Common);
            }
            chance += rare;
            if value < chance.into() {
                let number = seed.get_final_value(self.rare_attacks_amount.read());
                return (self.rare_attacks.read(number), Rarity::Rare);
            }
            chance += epic;
            if value < chance.into() {
                let number = seed.get_final_value(self.epic_attacks_amount.read());
                return (self.epic_attacks.read(number), Rarity::Epic);
            }
            chance += legendary;
            if value < chance.into() {
                let attack_n = seed.get_final_value(self.legendary_attacks_amount.read());

                return (self.legendary_attacks.read(attack_n), Rarity::Legendary);
            }
            return (0, Rarity::None);
        }
    }
}
