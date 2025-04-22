use core::{fmt::{Display, Formatter, Error, Debug}, cmp::{min, max}, poseidon::poseidon_hash_span};
use starknet::{ContractAddress, get_caller_address};
use dojo::{world::WorldStorage, model::{ModelStorage, Model}};
use blob_arena::{
    erc721::ERC721Token, core::{SaturatingInto, SaturatingAdd, in_range},
    constants::STARTING_HEALTH, combat::calculations::{apply_luck_modifier, get_new_stun_chance},
    stats::{UStats, IStats, StatsTrait, StatTypes}, utils, utils::SeedProbability,
    constants::{NZ_255},
};

/// Game Models

/// * `id` - The unique identifier for the combatant
/// * `combat_id` - The identifier for the current combat session
/// * `player` - The contract address of the player who owns this combatant
#[dojo::model]
#[derive(Drop, Serde, Copy)]
struct CombatantInfo {
    #[key]
    id: felt252,
    combat_id: felt252,
    player: ContractAddress,
}

/// Represents a token-based combatant in the blob arena game
///
/// # Arguments
/// * `id` - Unique identifier for the combatant
/// * `collection_address` - Contract address of the NFT collection
/// * `token_id` - Token ID within the collection representing this combatant
///
/// The CombatantToken struct links an NFT to a combatant in the game system,
/// enabling NFT-based character representation. It is a dojo model component
/// that can be used to track ownership and identify combatants.
#[dojo::model]
#[derive(Drop, Serde, Copy)]
struct CombatantToken {
    #[key]
    id: felt252,
    collection_address: ContractAddress,
    token_id: u256,
}


/// Represents the current state of a combatant in the game
///
/// # Fields
/// * `id` - Unique identifier for the combatant
/// * `health` - Current health points of the combatant (0-200) depends on vitality
/// * `stun_chance` - Probability of stunning an opponent (0-255)
/// * `stats` - The current stats of the combatant
///
/// This model is used to track the dynamic state of combatants during gameplay,
/// including their health status and combat-related attributes.

#[dojo::model]
#[derive(Drop, Serde, Copy, starknet::Event)]
struct CombatantState {
    #[key]
    id: felt252,
    health: u8,
    stun_chance: u8,
    stats: UStats,
}

#[derive(Drop)]
struct CombatantSetup {
    stats: UStats,
    attacks: Array<felt252>,
}


impl CombatantStateDisplayImpl of Display<CombatantState> {
    fn fmt(self: @CombatantState, ref f: Formatter) -> Result<(), Error> {
        write!(
            f,
            "id: {}, health: {}, stun_chance: {}, buffs: {:?}",
            self.id,
            self.health,
            self.stun_chance,
            *self.stats,
        )
    }
}

impl CombatantStateDebugImpl = utils::TDebugImpl<CombatantState>;

fn get_combatant_id(
    collection_address: ContractAddress, token_id: u256, combat_id: felt252,
) -> felt252 {
    poseidon_hash_span(
        [collection_address.into(), token_id.high.into(), token_id.low.into(), combat_id].span(),
    )
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

    fn apply_buffs(ref self: CombatantState, buffs: IStats) -> IStats {
        let change = self.stats.apply_buffs(buffs);
        self.cap_health();
        change
    }

    fn modify_health<T, +Into<u8, T>, +SaturatingAdd<T>, +SaturatingInto<T, u8>, +Drop<T>>(
        ref self: CombatantState, health: T,
    ) -> i32 {
        let starting_health: i32 = self.health.into();
        self
            .health =
                min(
                    self.get_max_health(),
                    self.health.into().saturating_add(health).saturating_into(),
                );
        self.health.into() - starting_health
    }

    fn apply_buff(ref self: CombatantState, stat: StatTypes, amount: i8) -> i8 {
        let result = self.stats.apply_buff(stat, amount);
        if stat == StatTypes::Vitality {
            self.cap_health();
        };
        result
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


#[generate_trait]
impl CombatantStorageImpl of CombatantStorage {
    fn get_combatant_info(self: @WorldStorage, id: felt252) -> CombatantInfo {
        self.read_model(id)
    }

    fn get_combatant_infos(self: @WorldStorage, ids: Span<felt252>) -> Array<CombatantInfo> {
        self.read_models(ids)
    }

    fn set_combatant_info(
        ref self: WorldStorage, id: felt252, combat_id: felt252, player: ContractAddress,
    ) {
        self.write_model(@CombatantInfo { id, combat_id, player });
    }

    fn set_combatant_combat_id(ref self: WorldStorage, id: felt252, combat_id: felt252) {
        self
            .write_member(
                Model::<CombatantInfo>::ptr_from_keys(id), selector!("combat_id"), combat_id,
            );
    }

    fn get_combatant_combat_id(self: @WorldStorage, id: felt252) -> felt252 {
        self.read_member(Model::<CombatantInfo>::ptr_from_keys(id), selector!("combat_id"))
    }
    fn create_combatant_state(ref self: WorldStorage, id: felt252, stats: UStats) {
        self.write_model(@make_combatant_state(id, @stats));
    }

    fn get_combatant_health(self: @WorldStorage, id: felt252) -> u8 {
        self.read_member(Model::<CombatantState>::ptr_from_keys(id), selector!("health"))
    }

    fn set_combatant_state(
        ref self: WorldStorage, combatant_id: felt252, health: u8, stun_chance: u8, stats: UStats,
    ) {
        self.write_model(@CombatantState { id: combatant_id, health, stun_chance, stats });
    }

    fn get_combatant_state(self: @WorldStorage, id: felt252) -> CombatantState {
        self.read_model(id)
    }

    fn get_combatant_states(self: @WorldStorage, ids: Span<felt252>) -> Array<CombatantState> {
        self.read_models(ids)
    }

    fn set_combatant_states(ref self: WorldStorage, states: Span<@CombatantState>) {
        self.write_models(states)
    }
    fn get_combatant_info_in_combat(self: @WorldStorage, id: felt252) -> CombatantInfo {
        let combatant = self.get_combatant_info(id);
        assert(combatant.combat_id.is_non_zero(), 'Not valid combatant');
        combatant
    }
    fn get_callers_combatant_info(self: @WorldStorage, id: felt252) -> CombatantInfo {
        let combatant = self.get_combatant_info(id);
        combatant.assert_caller();
        combatant
    }
    fn get_player(self: @WorldStorage, id: felt252) -> ContractAddress {
        self.read_member(Model::<CombatantInfo>::ptr_from_keys(id), selector!("player"))
    }

    fn get_combatant_token(self: @WorldStorage, id: felt252) -> ERC721Token {
        self.read_schema(Model::<CombatantToken>::ptr_from_keys(id))
    }

    fn get_combatant_token_address(self: @WorldStorage, id: felt252) -> ContractAddress {
        self
            .read_member(
                Model::<CombatantToken>::ptr_from_keys(id), selector!("collection_address"),
            )
    }

    fn set_combatant_token(
        ref self: WorldStorage, id: felt252, collection_address: ContractAddress, token_id: u256,
    ) {
        self.write_model(@CombatantToken { id, collection_address, token_id });
    }

    fn get_combatant_stats(self: @WorldStorage, id: felt252) -> UStats {
        self.read_member(Model::<CombatantState>::ptr_from_keys(id), selector!("stats"))
    }
    fn get_combatant_stun_chance(self: @WorldStorage, id: felt252) -> u8 {
        self.read_member(Model::<CombatantState>::ptr_from_keys(id), selector!("stun_chance"))
    }
}
