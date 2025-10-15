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
    use ba_utils::felt252_to_u128;
    use ba_utils::vrf::{VrfTrait, vrf_component};
    use core::num::traits::DivRem;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address};
    use super::IOrbMinter;
    const THOUSAND_NZ: NonZero<u128> = 1000;

    component!(path: vrf_component, storage: vrf, event: VrfEvents);

    #[storage]
    struct Storage {
        #[substorage(v0)]
        vrf: vrf_component::Storage,
        orb_contract: ContractAddress,
        common_attacks: Map<u32, felt252>,
        rare_attacks: Map<u32, felt252>,
        epic_attacks: Map<u32, felt252>,
        legendary_attacks: Map<u32, felt252>,
        attack_amounts: u128,
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        VrfEvents: vrf_component::Event,
    }


    impl IOrbMinterImpl of IOrbMinter<ContractState> {
        fn roll(ref self: ContractState, to: ContractAddress, chances_permille: [u32; 4]) -> u256 {
            let caller = get_caller_address();
            let mut seed = felt252_to_u128(self.get_nonce_seed(caller));
            let (_seed:, value) = seed.div_rem(THOUSAND_NZ);
            let [common, rare, epic, legendary] = chances_permille;
            let (attacks, amount, rarity: ) = if value < common.into(){

            } else if value < (common + rare).into(){

            } else if value < (common + rare + epic).into(){

            } else if value < (common + rare + epic + legendary).into(){

            } else {
                
            }
        }
    }
}
