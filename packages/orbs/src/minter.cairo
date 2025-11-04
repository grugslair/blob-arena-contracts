use sai_packing::shifts::{
    SHIFT_12B, SHIFT_12B_FELT252, SHIFT_13B, SHIFT_14B, SHIFT_16B_FELT252, SHIFT_20B_FELT252,
    SHIFT_24B_FELT252, SHIFT_28B_FELT252, SHIFT_29B_FELT252, SHIFT_30B_FELT252, SHIFT_4B,
    SHIFT_4B_FELT252, SHIFT_8B, SHIFT_8B_FELT252,
};
use sai_packing::{MaskDowncast, ShiftCast};
use starknet::ContractAddress;
use starknet::storage_access::StorePacking;

#[derive(Drop, Copy, Serde, Introspect, PartialEq, Default, starknet::Store)]
pub enum Rarity {
    #[default]
    None,
    Common,
    Rare,
    Epic,
    Legendary,
}

#[derive(Drop)]
pub enum RollResult {
    #[default]
    None,
    Orb: Rarity,
    Shard: (Rarity, u32),
}

#[derive(Drop, Serde)]
pub enum RollReward {
    #[default]
    None,
    Orb: (Rarity, felt252, u256),
    Shard: (Rarity, u32),
}


#[starknet::interface]
pub trait IOrbMinter<TState> {
    fn roll(
        ref self: TState, to: ContractAddress, drop_rates: OrbDropRates, randomness: u64,
    ) -> RollReward;
    fn combine_shards(ref self: TState, rarity: Rarity) -> (felt252, u256);
}

#[starknet::interface]
trait IOrbMinterAdmin<TState> {
    fn set_common_actions(ref self: TState, actions: Array<felt252>);
    fn set_rare_actions(ref self: TState, actions: Array<felt252>);
    fn set_epic_actions(ref self: TState, actions: Array<felt252>);
    fn set_legendary_actions(ref self: TState, actions: Array<felt252>);
    fn set_shards_in_orbs(ref self: TState, rare: u32, epic: u32, legendary: u32);
    fn set_charge(ref self: TState, charge: u128);
}


// Drop rates in ppm
#[derive(Drop, Introspect, Serde)]
pub struct OrbDropRates {
    common_full: u32,
    rare_full: u32,
    epic_full: u32,
    legendary_full: u32,
    rare_shard: u32,
    epic_shard: u32,
    legendary_shard: u32,
    max_rare_shards: u8,
    max_epic_shards: u8,
    max_legendary_shards: u8,
}


impl OrbDropRatesPacking of StorePacking<OrbDropRates, felt252> {
    fn pack(value: OrbDropRates) -> felt252 {
        value.common_full.into()
            + ShiftCast::const_cast::<SHIFT_4B_FELT252>(value.rare_full)
            + ShiftCast::const_cast::<SHIFT_8B_FELT252>(value.epic_full)
            + ShiftCast::const_cast::<SHIFT_12B_FELT252>(value.legendary_full)
            + ShiftCast::const_cast::<SHIFT_16B_FELT252>(value.rare_shard)
            + ShiftCast::const_cast::<SHIFT_20B_FELT252>(value.epic_shard)
            + ShiftCast::const_cast::<SHIFT_24B_FELT252>(value.legendary_shard)
            + ShiftCast::const_cast::<SHIFT_28B_FELT252>(value.max_rare_shards)
            + ShiftCast::const_cast::<SHIFT_29B_FELT252>(value.max_epic_shards)
            + ShiftCast::const_cast::<SHIFT_30B_FELT252>(value.max_legendary_shards)
    }

    fn unpack(value: felt252) -> OrbDropRates {
        let u256 { low, high } = value.into();
        OrbDropRates {
            common_full: MaskDowncast::cast(low),
            rare_full: ShiftCast::const_unpack::<SHIFT_4B>(low),
            epic_full: ShiftCast::const_unpack::<SHIFT_8B>(low),
            legendary_full: ShiftCast::const_unpack::<SHIFT_12B>(low),
            rare_shard: MaskDowncast::cast(high),
            epic_shard: ShiftCast::const_unpack::<SHIFT_4B>(low),
            legendary_shard: ShiftCast::const_unpack::<SHIFT_8B>(low),
            max_rare_shards: ShiftCast::const_unpack::<SHIFT_12B>(low),
            max_epic_shards: ShiftCast::const_unpack::<SHIFT_13B>(low),
            max_legendary_shards: ShiftCast::const_unpack::<SHIFT_14B>(low),
        }
    }
}

// impl OrbDropRatesSerde of Serde<OrbDropRates> {
//     fn serialize(value: @OrbDropRates, ref output: Array<felt252>) {
//         output.append(OrbDropRatesPacking::pack(*value));
//     }

//     fn deserialize(ref serialized: Span<felt252>) -> Option<OrbDropRates> {
//         match serialized.pop_front() {
//             None => None,
//             Some(felt) => Some(OrbDropRatesPacking::unpack(*felt)),
//         }
//     }
// }

#[derive(Drop, Serde, Introspect)]
struct Shards {
    pub common: u32,
    pub rare: u32,
    pub epic: u32,
    pub legendary: u32,
}

#[starknet::contract]
mod orb_minter {
    use ba_utils::SeedProbability;
    use ba_utils::vrf::{VrfTrait, vrf_component};
    use beacon_library::{ToriiTable, register_table_with_schema};
    use sai_access::{AccessTrait, access_component};
    use sai_packing::MaskDowncast;
    use starknet::storage::{
        Map, Mutable, StorageBase, StorageMapReadAccess, StorageMapWriteAccess,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address};
    use crate::OrbTrait;
    use super::{IOrbMinter, IOrbMinterAdmin, OrbDropRates, Rarity, RollResult, RollReward, Shards};
    const MILLION_NZ: NonZero<u64> = 1000000;

    const TABLE_HASH: felt252 = bytearrays_hash!("orbs", "Shards");
    impl ShardsTable = ToriiTable<TABLE_HASH>;

    component!(path: vrf_component, storage: vrf, event: VrfEvents);
    component!(path: access_component, storage: access, event: AccessEvents);


    #[storage]
    struct Storage {
        #[substorage(v0)]
        vrf: vrf_component::Storage,
        #[substorage(v0)]
        access: access_component::Storage,
        orb_contract: ContractAddress,
        common_actions: Map<u32, felt252>,
        rare_actions: Map<u32, felt252>,
        epic_actions: Map<u32, felt252>,
        legendary_actions: Map<u32, felt252>,
        common_actions_amount: u32,
        rare_actions_amount: u32,
        epic_actions_amount: u32,
        legendary_actions_amount: u32,
        rare_shards: Map<ContractAddress, u32>,
        epic_shards: Map<ContractAddress, u32>,
        legendary_shards: Map<ContractAddress, u32>,
        rare_shards_in_orb: u32,
        epic_shards_in_orb: u32,
        legendary_shards_in_orb: u32,
        charge: u128,
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        VrfEvents: vrf_component::Event,
        #[flat]
        AccessEvents: access_component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, owner: ContractAddress, token_address: ContractAddress,
    ) {
        register_table_with_schema::<Shards>("orbs", "Shards");
        self.grant_owner(owner);
        self.orb_contract.write(token_address);
    }

    #[abi(embed_v0)]
    impl IOrbMinterImpl of IOrbMinter<ContractState> {
        fn roll(
            ref self: ContractState,
            to: ContractAddress,
            drop_rates: OrbDropRates,
            mut randomness: u64,
        ) -> RollReward {
            self.assert_caller_is_writer();
            let rarity = self.get_random_rarity(drop_rates, ref randomness);
            match rarity {
                RollResult::Orb(rarity) => {
                    let (action, token_id) = self.mint_random_action(to, rarity, randomness);
                    RollReward::Orb((rarity, action, token_id))
                },
                RollResult::Shard((
                    rarity, amount,
                )) => {
                    self.mint_shards(to, rarity, amount);
                    RollReward::Shard((rarity, amount))
                },
                RollResult::None => RollReward::None,
            }
        }

        fn combine_shards(ref self: ContractState, rarity: Rarity) -> (felt252, u256) {
            let caller = get_caller_address();
            let mut randomness = MaskDowncast::cast(self.get_nonce_seed(caller));
            let (shard_ptr, selector, shards_in_orb) = match rarity {
                Rarity::Rare => (
                    self.rare_shards, selector!("rare"), self.rare_shards_in_orb.read(),
                ),
                Rarity::Epic => (
                    self.epic_shards, selector!("epic"), self.epic_shards_in_orb.read(),
                ),
                Rarity::Legendary => (
                    self.legendary_shards,
                    selector!("legendary"),
                    self.legendary_shards_in_orb.read(),
                ),
                _ => panic!("Invalid rarity for combining shards"),
            };

            let amount_of_shards = shard_ptr.read(caller);
            assert(amount_of_shards >= shards_in_orb, 'Not enough shards to combine');
            self.set_shards(shard_ptr, selector, caller, amount_of_shards - shards_in_orb);
            self.mint_random_action(caller, rarity, randomness)
        }
    }
    #[abi(embed_v0)]
    impl IOrbMinterAdminImpl of IOrbMinterAdmin<ContractState> {
        fn set_common_actions(ref self: ContractState, actions: Array<felt252>) {
            self.assert_caller_is_owner();
            self.common_actions_amount.write(actions.len());
            for (i, action) in actions.into_iter().enumerate() {
                self.common_actions.write(i, action);
            }
        }

        fn set_rare_actions(ref self: ContractState, actions: Array<felt252>) {
            self.assert_caller_is_owner();
            self.rare_actions_amount.write(actions.len());
            for (i, action) in actions.into_iter().enumerate() {
                self.rare_actions.write(i, action);
            }
        }

        fn set_epic_actions(ref self: ContractState, actions: Array<felt252>) {
            self.assert_caller_is_owner();
            self.epic_actions_amount.write(actions.len());
            for (i, action) in actions.into_iter().enumerate() {
                self.epic_actions.write(i, action);
            }
        }

        fn set_legendary_actions(ref self: ContractState, actions: Array<felt252>) {
            self.assert_caller_is_owner();
            self.legendary_actions_amount.write(actions.len());
            for (i, action) in actions.into_iter().enumerate() {
                self.legendary_actions.write(i, action);
            }
        }

        fn set_shards_in_orbs(ref self: ContractState, rare: u32, epic: u32, legendary: u32) {
            self.assert_caller_is_owner();
            self.rare_shards_in_orb.write(rare.try_into().unwrap());
            self.epic_shards_in_orb.write(epic.try_into().unwrap());
            self.legendary_shards_in_orb.write(legendary.try_into().unwrap());
        }

        fn set_charge(ref self: ContractState, charge: u128) {
            self.assert_caller_is_owner();
            self.charge.write(charge);
        }
    }


    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn get_random_rarity(
            self: @ContractState, drop_rates: OrbDropRates, ref randomness: u64,
        ) -> RollResult {
            let value: u32 = randomness.get_value_nz(MILLION_NZ);
            let OrbDropRates {
                common_full,
                rare_full,
                epic_full,
                legendary_full,
                rare_shard,
                epic_shard,
                legendary_shard,
                max_rare_shards,
                max_epic_shards,
                max_legendary_shards,
            } = drop_rates;
            let mut chance = common_full;
            if value < chance {
                return RollResult::Orb(Rarity::Common);
            }
            chance += rare_full;
            if value < chance {
                return RollResult::Orb(Rarity::Rare);
            }
            chance += epic_full;
            if value < chance {
                return RollResult::Orb(Rarity::Epic);
            }
            chance += legendary_full;
            if value < chance {
                return RollResult::Orb(Rarity::Legendary);
            }
            chance += rare_shard;
            if value < chance {
                return RollResult::Shard(
                    (Rarity::Rare, randomness.get_value(max_rare_shards).into()),
                );
            }
            chance += epic_shard;
            if value < chance {
                return RollResult::Shard(
                    (Rarity::Epic, randomness.get_value(max_epic_shards).into()),
                );
            }
            chance += legendary_shard;
            if value < chance {
                return RollResult::Shard(
                    (Rarity::Legendary, randomness.get_value(max_legendary_shards).into()),
                );
            }
            RollResult::None
        }

        fn mint_random_action(
            ref self: ContractState, owner: ContractAddress, rarity: Rarity, randomness: u64,
        ) -> (felt252, u256) {
            let (amount, actions_ptr) = match rarity {
                Rarity::Common => (self.common_actions_amount.read(), self.common_actions),
                Rarity::Rare => (self.rare_actions_amount.read(), self.rare_actions),
                Rarity::Epic => (self.epic_actions_amount.read(), self.epic_actions),
                Rarity::Legendary => (self.legendary_actions_amount.read(), self.legendary_actions),
                Rarity::None => { return (0, 0); },
            };
            let action = actions_ptr.read(randomness.get_final_value(amount));

            let charge = self.charge.read();
            (action, self.orb_contract.read().mint(owner, action, charge, charge))
        }

        fn get_shards_ptr_selector(
            ref self: ContractState, rarity: Rarity,
        ) -> (StorageBase<Mutable<Map<ContractAddress, u32>>>, felt252) {
            match rarity {
                Rarity::Rare => (self.rare_shards, selector!("rare")),
                Rarity::Epic => (self.epic_shards, selector!("epic")),
                Rarity::Legendary => (self.legendary_shards, selector!("legendary")),
                _ => panic!("Invalid rarity for shards"),
            }
        }

        fn mint_shards(ref self: ContractState, to: ContractAddress, rarity: Rarity, amount: u32) {
            let (ptr, selector) = self.get_shards_ptr_selector(rarity);
            self.set_shards(ptr, selector, to, ptr.read(to) + amount);
        }

        fn set_shards(
            ref self: ContractState,
            ptr: StorageBase<Mutable<Map<ContractAddress, u32>>>,
            selector: felt252,
            to: ContractAddress,
            amount: u32,
        ) {
            ptr.write(to, amount);
            ShardsTable::set_member(selector, to, @amount);
        }
    }
}
