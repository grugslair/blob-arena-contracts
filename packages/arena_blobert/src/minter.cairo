use ba_blobert::{Seed, TokenAttributes};
use ba_utils::{SeedProbability, felt252_to_u128};
use starknet::ContractAddress;

const BACKGROUND_COUNT: u128 = 8;
const ARMOUR_COUNT: u128 = 8;
const JEWELRY_COUNT: u128 = 8;
const WEAPON_COUNT: u128 = 8;
const MASK_COUNT: u128 = 8;

#[starknet::interface]
trait IArcadeBlobertMinter<TState> {
    fn mint(ref self: TState) -> u256;
}

#[starknet::interface]
trait IArenaBlobert<TState> {
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
    fn mint(ref self: TState, owner: ContractAddress, attributes: TokenAttributes) -> u256;
}


fn generate_seed(randomness: felt252) -> Seed {
    let mut seed: u128 = felt252_to_u128(randomness);

    let background: u32 = seed.get_value(BACKGROUND_COUNT).try_into().unwrap();
    let armour: u32 = seed.get_value(ARMOUR_COUNT).try_into().unwrap();
    let jewelry: u32 = seed.get_value(JEWELRY_COUNT).try_into().unwrap();
    let weapon: u32 = seed.get_value(WEAPON_COUNT).try_into().unwrap();

    let mask_count = if armour <= 1 {
        8
    } else {
        MASK_COUNT // exclude the first two masks for other armours
    };
    let mask: u32 = seed.get_value(mask_count).try_into().unwrap();

    return Seed { background, armour, jewelry, mask, weapon };
}

#[starknet::contract]
mod arena_blobert_minter {
    use ba_blobert::TokenAttributes;
    use core::poseidon::poseidon_hash_span;
    use sai_access::{AccessTrait, access_component};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use super::{
        IArcadeBlobertMinter, IArenaBlobertDispatcher, IArenaBlobertDispatcherTrait, generate_seed,
    };

    component!(path: access_component, storage: access, event: AccessEvents);

    #[storage]
    struct Storage {
        #[substorage(v0)]
        access: access_component::Storage,
        token_contract: IArenaBlobertDispatcher,
        last_mint: Map<ContractAddress, u64>,
        min_mint_time: u64,
        max_bloberts: u32,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccessEvents: access_component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, owner: ContractAddress, token_address: ContractAddress,
    ) {
        self.grant_owner(owner);
        self.token_contract.write(IArenaBlobertDispatcher { contract_address: token_address });
    }


    #[abi(embed_v0)]
    impl IAccessImpl = access_component::AccessImpl<ContractState>;

    #[abi(embed_v0)]
    impl IArcadeBlobertMinterImpl of IArcadeBlobertMinter<ContractState> {
        fn mint(ref self: ContractState) -> u256 {
            let timestamp = get_block_timestamp();

            let caller = get_caller_address();
            // TODO: make randomness
            let randomness = poseidon_hash_span([].span());
            let mut token_contract = self.token_contract.read();
            assert(
                self.last_mint.read(caller) + self.min_mint_time.read() <= timestamp,
                'Cannot mint yet',
            );
            assert(
                self.max_bloberts.read() > token_contract.balance_of(caller).try_into().unwrap(),
                'Max bloberts reached',
            );
            self.last_mint.write(caller, timestamp);
            token_contract.mint(caller, TokenAttributes::Seed(generate_seed(randomness)))
        }
    }
}
