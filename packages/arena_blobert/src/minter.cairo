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
trait IArcadeBlobertMinterAdmin<TState> {
    fn set_min_mint_time(ref self: TState, min_mint_time: u64);
    fn set_max_bloberts(ref self: TState, max_bloberts: u32);
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

#[derive(Drop, Serde, Introspect)]
struct LastMint {
    last_mint: u64,
}

#[starknet::contract]
mod arena_blobert_minter {
    use ba_blobert::TokenAttributes;
    use ba_utils::uuid;
    use beacon_library::{ToriiTable, register_table_with_schema};
    use sai_ownable::{OwnableTrait, ownable_component};
    use sai_return::emit_return;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use super::{
        IArcadeBlobertMinter, IArcadeBlobertMinterAdmin, IArenaBlobertDispatcher,
        IArenaBlobertDispatcherTrait, LastMint, generate_seed,
    };

    component!(path: ownable_component, storage: ownable, event: OwnableEvents);

    const LAST_MINT_TABLE_ID: felt252 = bytearrays_hash!("arena_blobert", "LastMint");
    impl LastMintTable = ToriiTable<LAST_MINT_TABLE_ID>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: ownable_component::Storage,
        token_contract: IArenaBlobertDispatcher,
        last_mint: Map<ContractAddress, u64>,
        min_mint_time: u64,
        max_bloberts: u32,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvents: ownable_component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, owner: ContractAddress, token_address: ContractAddress,
    ) {
        self.grant_owner(owner);
        self.token_contract.write(IArenaBlobertDispatcher { contract_address: token_address });
        register_table_with_schema::<LastMint>("arena_blobert", "LastMint");
    }


    #[abi(embed_v0)]
    impl IOwnableImpl = ownable_component::OwnableImpl<ContractState>;

    #[abi(embed_v0)]
    impl IArcadeBlobertMinterImpl of IArcadeBlobertMinter<ContractState> {
        fn mint(ref self: ContractState) -> u256 {
            let timestamp = get_block_timestamp();

            let caller = get_caller_address();
            // TODO: make randomness
            let randomness = uuid();
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
            LastMintTable::set_entity(caller, @timestamp);

            emit_return(
                token_contract.mint(caller, TokenAttributes::Seed(generate_seed(randomness))),
            )
        }
    }

    #[abi(embed_v0)]
    impl IArcadeBlobertMinterAdminImpl of IArcadeBlobertMinterAdmin<ContractState> {
        fn set_min_mint_time(ref self: ContractState, min_mint_time: u64) {
            self.ownable.caller_is_owner();
            self.min_mint_time.write(min_mint_time);
        }
        fn set_max_bloberts(ref self: ContractState, max_bloberts: u32) {
            self.ownable.caller_is_owner();
            self.max_bloberts.write(max_bloberts);
        }
    }
}
