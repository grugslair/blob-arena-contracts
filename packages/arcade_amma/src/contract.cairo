use ba_loadout::PartialAttributes;
use ba_loadout::action::IdTagAction;
use ba_utils::storage::{FeltArrayReadWrite, ShortArrayStore};

/// Input structure for configuring Amma arcade opponents
///
/// Used when setting up or adding opponents to the arcade opponent pool.
/// Contains the raw action definitions that will be processed into action IDs.
///
/// # Fields
/// * `base` - Base attribute modifiers applied to the opponent regardless of stage
/// * `level` - Per-level attribute scaling modifiers (multiplied by stage number, capped at 10)
/// * `actions` - Array of action definitions that will be created/resolved to action IDs
#[derive(Drop, Serde)]
struct AmmaOpponentInput {
    base: PartialAttributes,
    level: PartialAttributes,
    actions: Array<IdTagAction>,
}

#[derive(Drop, Serde, Introspect, starknet::Store)]
struct AmmaOpponent {
    base: PartialAttributes,
    level: PartialAttributes,
    actions: Array<felt252>,
}

impl AmmaOpponentInputIntoParts of Into<
    AmmaOpponentInput, ([PartialAttributes; 2], Array<IdTagAction>),
> {
    fn into(self: AmmaOpponentInput) -> ([PartialAttributes; 2], Array<IdTagAction>) {
        ([self.base, self.level], self.actions)
    }
}

/// Interface for managing Amma-specific arcade configuration and opponents
///
/// Provides functionality to configure the arcade stages, manage opponent pools,
/// and set up the procedurally generated opponents that players will face.
#[starknet::interface]
trait IArcadeAmma<TState> {
    /// Gets the number of procedurally generated stages in the arcade
    ///
    /// # Returns
    /// * `u32` - Number of generated stages before the boss stage
    fn gen_stages(self: @TState) -> u32;

    /// Sets the number of procedurally generated stages in the arcade
    ///
    /// # Arguments
    /// * `gen_stages` - Number of generated stages (boss stage is additional)
    fn set_gen_stages(ref self: TState, gen_stages: u32);

    /// Gets the total number of opponents available in the opponent pool
    ///
    /// # Returns
    /// * `u32` - Total count of configured opponents
    fn opponent_count(self: @TState) -> u32;

    /// Retrieves a specific opponent configuration by fighter ID
    ///
    /// # Arguments
    /// * `fighter` - Unique identifier of the opponent to retrieve
    ///
    /// # Returns
    /// * `AmmaOpponent` - Complete opponent configuration including attributes and actions
    fn opponent(self: @TState, fighter: u32) -> AmmaOpponent;

    /// Sets or updates a specific opponent in the opponent pool
    ///
    /// # Arguments
    /// * `fighter` - Unique identifier for this opponent
    /// * `base` - Base attribute modifiers for this opponent
    /// * `level` - Per-level attribute scaling modifiers
    /// * `actions` - Array of actions available to this opponent
    fn set_opponent(
        ref self: TState,
        fighter: u32,
        base: PartialAttributes,
        level: PartialAttributes,
        actions: Array<IdTagAction>,
    );

    /// Adds a new opponent to the opponent pool
    ///
    /// Creates a new opponent with the next available fighter ID and increments
    /// the opponent count.
    ///
    /// # Arguments
    /// * `base` - Base attribute modifiers for this opponent
    /// * `level` - Per-level attribute scaling modifiers
    /// * `actions` - Array of actions available to this opponent
    fn add_opponent(
        ref self: TState,
        base: PartialAttributes,
        level: PartialAttributes,
        actions: Array<IdTagAction>,
    );

    /// Replaces the entire opponent pool with new opponents
    ///
    /// Clears existing opponents and sets up new ones starting from fighter ID 0.
    ///
    /// # Arguments
    /// * `opponents` - Array of opponent configurations to set as the new pool
    fn set_opponents(ref self: TState, opponents: Array<AmmaOpponentInput>);

    /// Adds multiple new opponents to the existing opponent pool
    ///
    /// Appends new opponents to the current pool, maintaining existing opponents.
    ///
    /// # Arguments
    /// * `opponents` - Array of opponent configurations to add to the pool
    fn add_opponents(ref self: TState, opponents: Array<AmmaOpponentInput>);
}

#[starknet::contract]
mod arcade_amma {
    use ba_arcade::attempt::{ArcadeProgress, AttemptNodeTrait};
    use ba_arcade::{IArcade, Opponent, arcade_component};
    use ba_combat::Move;
    use ba_combat::systems::get_action_dispatcher_address;
    use ba_loadout::PartialAttributes;
    use ba_loadout::action::interface::maybe_create_actions_array;
    use ba_loadout::action::maybe_create_actions;
    use ba_loadout::attributes::AttributesCalcTrait;
    use ba_loadout::loadout_amma::{get_fighter_count, get_fighter_loadout};
    use ba_utils::vrf::vrf_component;
    use ba_utils::{CapInto, Randomness, RandomnessTrait};
    use beacon_library::{ToriiTable, register_table_with_schema};
    use sai_core_utils::poseidon_hash_two;
    use sai_ownable::{OwnableTrait, ownable_component};
    use sai_return::emit_return;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ClassHash, ContractAddress};
    use crate::systems::{action_slots, random_selection};
    use super::{AmmaOpponent, AmmaOpponentInput, IArcadeAmma, IdTagAction};

    component!(path: ownable_component, storage: ownable, event: OwnableEvents);
    component!(path: arcade_component, storage: arcade, event: ArcadeEvents);
    component!(path: vrf_component, storage: vrf, event: VrfEvents);


    const ROUND_HASH: felt252 = bytearrays_hash!("arcade_amma", "Round");
    const ATTEMPT_HASH: felt252 = bytearrays_hash!("arcade_amma", "Attempt");
    const COMBAT_HASH: felt252 = bytearrays_hash!("arcade_amma", "Combat");
    const LAST_USED_ATTACK_HASH: felt252 = bytearrays_hash!("arcade_amma", "ActionLastUsed");
    const STAGE_OPPONENTS_HASH: felt252 = bytearrays_hash!("arcade_amma", "StageOpponents");
    const OPPONENTS_HASH: felt252 = bytearrays_hash!("arcade_amma", "Opponent");

    impl StageOpponentsTable = ToriiTable<STAGE_OPPONENTS_HASH>;
    impl ArcadeInternal =
        arcade_component::ArcadeInternal<
            ContractState, ATTEMPT_HASH, COMBAT_HASH, ROUND_HASH, LAST_USED_ATTACK_HASH,
        >;
    impl OpponentTable = ToriiTable<OPPONENTS_HASH>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: ownable_component::Storage,
        #[substorage(v0)]
        arcade: arcade_component::Storage,
        #[substorage(v0)]
        vrf: vrf_component::Storage,
        collectable_address: ContractAddress,
        gen_stages: u32,
        opponents: Map<u32, AmmaOpponent>,
        opponent_count: u32,
        stage_opponents: Map<felt252, u32>,
        bosses: Map<felt252, u32>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvents: ownable_component::Event,
        #[flat]
        ArcadeEvents: arcade_component::Event,
        #[flat]
        VrfEvents: vrf_component::Event,
    }

    #[derive(Drop, Serde, Introspect)]
    struct StageOpponents {
        generated: Array<u32>,
        boss: u32,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        arcade_round_result_class_hash: ClassHash,
        action_address: ContractAddress,
        loadout_address: ContractAddress,
        collectable_address: ContractAddress,
    ) {
        self.grant_owner(owner);
        ArcadeInternal::init(
            ref self.arcade,
            "arcade_amma",
            arcade_round_result_class_hash,
            action_address,
            loadout_address,
        );
        register_table_with_schema::<StageOpponents>("arcade_amma", "StageOpponents");
        register_table_with_schema::<AmmaOpponent>("arcade_amma", "Opponent");
        self.collectable_address.write(collectable_address);
    }

    #[abi(embed_v0)]
    impl IOwnableImpl = ownable_component::OwnableImpl<ContractState>;

    #[abi(embed_v0)]
    impl IVrfImpl = vrf_component::VrfImpl<ContractState>;

    #[abi(embed_v0)]
    impl IArcadeImpl of IArcade<ContractState> {
        fn start(
            ref self: ContractState,
            collection_address: ContractAddress,
            token_id: u256,
            action_slots: Array<Array<felt252>>,
        ) -> felt252 {
            let (mut attempt_ptr, attempt_id, loadout_address) = ArcadeInternal::start_attempt(
                ref self.arcade, collection_address, token_id, action_slots,
            );
            let mut randomness = ArcadeInternal::consume_randomness(ref self.arcade, attempt_id);
            let opponents = random_selection(
                ref randomness, self.opponent_count.read(), self.gen_stages.read(),
            );
            ArcadeInternal::new_combat(
                ref self.arcade,
                ref attempt_ptr,
                attempt_id,
                0,
                0,
                self.gen_opponent(loadout_address, *opponents[0], 0),
                None,
            );
            StageOpponentsTable::set_entity(attempt_id, @(opponents.span(), 0));
            for (i, opponent) in opponents.into_iter().enumerate() {
                self.stage_opponents.write(poseidon_hash_two(attempt_id, i), opponent);
            }

            emit_return(attempt_id)
        }

        fn act(ref self: ContractState, attempt_id: felt252, action: Move) {
            let (mut attempt_ptr, result, mut randomness) = ArcadeInternal::act_attempt(
                ref self.arcade, attempt_id, action,
            );

            if result.phase == ArcadeProgress::PlayerWon {
                let next_stage = result.stage + 1;
                let gen_stages = self.gen_stages.read();
                if next_stage == gen_stages + 1 {
                    ArcadeInternal::set_phase(
                        ref attempt_ptr, attempt_id, ArcadeProgress::PlayerWon,
                    );
                } else if attempt_ptr.is_not_expired() {
                    attempt_ptr.stage.write(next_stage);
                    let health = result.health;
                    let loadout_address = self.arcade.loadout_address.read();
                    let opponent = match next_stage == gen_stages {
                        true => self.gen_boss_opponent(attempt_id, ref randomness),
                        false => self.gen_opponent_stage(loadout_address, attempt_id, next_stage),
                    };

                    ArcadeInternal::new_combat(
                        ref self.arcade,
                        ref attempt_ptr,
                        attempt_id,
                        result.combat_n + 1,
                        next_stage,
                        opponent,
                        Some(health),
                    );
                } else {
                    ArcadeInternal::set_loss(ref self.arcade, ref attempt_ptr, attempt_id);
                }
            }
        }

        fn respawn(ref self: ContractState, attempt_id: felt252) {
            let (mut attempt_ptr, combat_n, stage) = ArcadeInternal::respawn_attempt(
                ref self.arcade, attempt_id,
            );

            let opponent = match stage == self.gen_stages.read() {
                true => self.read_boss_opponent(attempt_id),
                false => self
                    .gen_opponent_stage(self.arcade.loadout_address.read(), attempt_id, stage),
            };

            ArcadeInternal::new_combat(
                ref self.arcade,
                ref attempt_ptr,
                attempt_id,
                combat_n + 1,
                stage + 1,
                opponent,
                None,
            );
        }


        fn forfeit(ref self: ContractState, attempt_id: felt252) {
            ArcadeInternal::forfeit_attempt(ref self.arcade, attempt_id);
        }
    }

    #[abi(embed_v0)]
    impl IArcadeSettings = arcade_component::ArcadeSettingsImpl<ContractState>;

    #[abi(embed_v0)]
    impl IArcadeAmmaImpl of IArcadeAmma<ContractState> {
        fn gen_stages(self: @ContractState) -> u32 {
            self.gen_stages.read()
        }

        fn set_gen_stages(ref self: ContractState, gen_stages: u32) {
            self.assert_caller_is_owner();
            self.gen_stages.write(gen_stages);
        }

        fn opponent_count(self: @ContractState) -> u32 {
            self.opponent_count.read()
        }

        fn opponent(self: @ContractState, fighter: u32) -> AmmaOpponent {
            self.opponents.read(fighter)
        }

        fn set_opponent(
            ref self: ContractState,
            fighter: u32,
            base: PartialAttributes,
            level: PartialAttributes,
            actions: Array<IdTagAction>,
        ) {
            self.assert_caller_is_owner();
            let action_ids = maybe_create_actions(get_action_dispatcher_address(), actions);
            self.set_opponent_internal(fighter, base, level, action_ids);
        }

        fn add_opponent(
            ref self: ContractState,
            base: PartialAttributes,
            level: PartialAttributes,
            actions: Array<IdTagAction>,
        ) {
            self.assert_caller_is_owner();
            let fighter = self.opponent_count.read();
            let action_ids = maybe_create_actions(get_action_dispatcher_address(), actions);
            self.set_opponent_internal(fighter, base, level, action_ids);
            self.opponent_count.write(fighter + 1);
        }

        fn set_opponents(ref self: ContractState, opponents: Array<AmmaOpponentInput>) {
            self.assert_caller_is_owner();
            self.set_opponents_internal(0, opponents);
        }

        fn add_opponents(ref self: ContractState, opponents: Array<AmmaOpponentInput>) {
            self.assert_caller_is_owner();
            self.set_opponents_internal(self.opponent_count.read(), opponents);
        }
    }


    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn gen_opponent_stage(
            self: @ContractState, loadout_address: ContractAddress, attempt_id: felt252, stage: u32,
        ) -> Opponent {
            self
                .gen_opponent(
                    loadout_address,
                    self.stage_opponents.read(poseidon_hash_two(attempt_id, stage)),
                    stage,
                )
        }

        fn set_opponents_internal(
            ref self: ContractState, starting_count: u32, opponents: Array<AmmaOpponentInput>,
        ) {
            let mut all_actions: Array<Array<IdTagAction>> = Default::default();
            let mut attributes: Array<[PartialAttributes; 2]> = Default::default();
            self.opponent_count.write(opponents.len() + starting_count);
            for opponent in opponents {
                let (attr, actions) = opponent.into();
                all_actions.append(actions);
                attributes.append(attr);
            }
            let all_action_ids = maybe_create_actions_array(
                get_action_dispatcher_address(), all_actions,
            );
            for (i, ([base, level], actions)) in attributes
                .into_iter()
                .zip(all_action_ids)
                .enumerate() {
                self.set_opponent_internal(i + starting_count + 1, base, level, actions);
            }
        }

        fn set_opponent_internal(
            ref self: ContractState,
            fighter: u32,
            base: PartialAttributes,
            level: PartialAttributes,
            actions: Array<felt252>,
        ) {
            let opponent = AmmaOpponent { base, level, actions };
            OpponentTable::set_entity(fighter, @opponent);
            self.opponents.write(fighter, opponent);
        }

        fn gen_opponent(
            self: @ContractState, loadout_address: ContractAddress, fighter: u32, stage: u32,
        ) -> Opponent {
            let AmmaOpponent { base, level, actions } = self.opponents.read(fighter);
            let attributes = (level.into().mul(stage.cap_into(10)) + base.into()).finalize();
            Opponent { attributes, actions }
        }

        fn gen_boss_opponent(
            ref self: ContractState, attempt_id: felt252, ref randomness: Randomness,
        ) -> Opponent {
            let loadout_address = self.arcade.loadout_address.read();
            let count = get_fighter_count(loadout_address);
            let fighter: u32 = randomness.final(count) + 1;

            StageOpponentsTable::set_member(selector!("boss"), attempt_id, @fighter);
            self.bosses.write(attempt_id, fighter);
            self.boss_opponent(loadout_address, fighter)
        }

        fn read_boss_opponent(self: @ContractState, attempt_id: felt252) -> Opponent {
            let fighter = self.bosses.read(attempt_id);
            self.boss_opponent(self.arcade.loadout_address.read(), fighter)
        }

        fn boss_opponent(
            self: @ContractState, loadout_address: ContractAddress, fighter: u32,
        ) -> Opponent {
            let (attributes, actions) = get_fighter_loadout(
                loadout_address, fighter, action_slots(),
            );
            Opponent { attributes, actions }
        }
    }
}
