use core::{fmt::{Display, Formatter, Error, Debug}, cmp::{min, max}};
use starknet::{ContractAddress, get_caller_address};
use dojo::{world::WorldStorage, model::ModelStorage};
use blob_arena::{
    core::{SaturatingInto, SaturatingAdd, in_range}, constants::STARTING_HEALTH,
    combat::calculations::{apply_luck_modifier, get_new_stun_chance},
    stats::{UStats, IStats, StatsTrait, StatTypes}, utils, utils::SeedProbability, hash::hash_value,
    constants::{NZ_255}
};


#[dojo::model]
#[derive(Drop, Serde, Copy)]
struct CombatantInfo {
    #[key]
    id: felt252,
    combat_id: felt252,
    player: ContractAddress,
}

#[dojo::model]
#[derive(Drop, Serde, Copy)]
struct CombatantToken {
    #[key]
    id: felt252,
    collection_address: ContractAddress,
    token_id: u256,
}

#[dojo::model]
#[derive(Drop, Serde, Copy)]
struct CombatantState {
    #[key]
    id: felt252,
    health: u8,
    stun_chance: u8,
    stats: UStats,
}


impl CombatantStateDisplayImpl of Display<CombatantState> {
    fn fmt(self: @CombatantState, ref f: Formatter) -> Result<(), Error> {
        write!(
            f,
            "id: {}, health: {}, stun_chance: {}, buffs: {:?}",
            self.id,
            self.health,
            self.stun_chance,
            *self.stats
        )
    }
}

impl CombatantStateDebugImpl = utils::TDebugImpl<CombatantState>;

fn get_combatant_id(
    collection_address: ContractAddress, token_id: u256, combat_id: felt252
) -> felt252 {
    hash_value((collection_address, token_id, combat_id))
}

fn max_health(vitality: u8) -> u8 {
    (vitality + STARTING_HEALTH).saturating_into()
}

fn make_combatant_state(id: felt252, stats: @UStats) -> CombatantState {
    CombatantState { id, health: max_health(*stats.vitality), stun_chance: 0, stats: *stats }
}

fn make_stat_in_range(base: u8, buff: i8) -> i8 {
    in_range(-(base).try_into().unwrap(), (100 - base).try_into().unwrap(), buff)
}

#[generate_trait]
impl CombatantInfoImpl of CombatantInfoTrait {
    fn assert_caller(self: CombatantInfo) -> ContractAddress {
        assert(get_caller_address() == self.player, 'Not combatant player'); //#
        self.player
    }
}


#[generate_trait]
impl CombatantStateImpl of CombatantStateTrait {
    fn limit_buffs(ref self: CombatantState) {
        self.stats.limit_stats();
    }

    fn apply_buffs(ref self: CombatantState, buffs: @IStats) {
        self.stats.apply_buffs(buffs);
        self.cap_health();
    }

    fn modify_health<T, +Into<u8, T>, +SaturatingAdd<T>, +SaturatingInto<T, u8>, +Drop<T>>(
        ref self: CombatantState, health: T
    ) {
        self
            .health =
                min(
                    self.get_max_health(),
                    self.health.into().saturating_add(health).saturating_into()
                );
    }

    fn apply_buff(ref self: CombatantState, stat: StatTypes, amount: i8) {
        self.stats.apply_buff(stat, amount);
        if stat == StatTypes::Vitality {
            self.cap_health();
        };
    }

    fn cap_health(ref self: CombatantState) {
        self.health = min(self.get_max_health(), self.health);
    }

    fn get_max_health(self: @CombatantState) -> u8 {
        self.stats.get_max_health()
    }

    fn run_stun(ref self: CombatantState, ref seed: u128) -> bool {
        let stun_chance: u8 = apply_luck_modifier(self.stun_chance, 100 - self.stats.luck);
        self.stun_chance = 0;
        seed.get_outcome(NZ_255, stun_chance)
    }

    fn apply_stun(ref self: CombatantState, stun: u8) {
        self.stun_chance = get_new_stun_chance(self.stun_chance, stun)
    }
}
