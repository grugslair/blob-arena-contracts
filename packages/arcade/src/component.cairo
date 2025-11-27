use starknet::ContractAddress;
use crate::attempt::ArcadeProgress;

mod errors {
    pub const RESPAWN_WHEN_NOT_LOST: felt252 = 'Cannot respawn, player not lost';
    pub const NOT_ACTIVE: felt252 = 'Combat is not active';
    pub const MAX_RESPAWNS_REACHED: felt252 = 'Max respawns reached';
}

#[derive(Drop)]
pub struct ArcadeActionResult {
    pub player: ContractAddress,
    pub phase: ArcadeProgress,
    pub stage: u32,
    pub combat_n: u32,
    pub health: u8,
}

#[starknet::component]
pub mod arcade_component {
    use ba_arcade::IArcadeSetup;
    use ba_arcade::attempt::{ArcadeProgress, AttemptNode, AttemptNodePath, AttemptNodeTrait};
    use ba_arcade::table::{ActionLastUsed, ArcadeAttemptTable};
    use ba_combat::combat::ActionCheck;
    use ba_combat::combatant::get_max_health_percent;
    use ba_combat::opponent::Opponent;
    use ba_combat::result::MoveResult;
    use ba_combat::systems::{get_action_dispatcher, set_action_dispatcher_address};
    use ba_combat::{CombatantState, CombatantStateTrait, Move, library_run_round};
    use ba_credit::arena_credit_consume;
    use ba_loadout::get_loadout;
    use ba_orbs::{IOrbMinterDispatcher, IOrbMinterDispatcherTrait, OrbDropRates, OrbTrait};
    use ba_utils::vrf::{HasVrfComponent, VrfTrait};
    use ba_utils::{Randomness, RandomnessTrait, erc721_token_hash, uuid};
    use beacon_library::{
        ToriiTable, register_table, register_table_with_schema, set_entity, set_member,
    };
    use core::num::traits::Zero;
    use core::panic_with_const_felt252;
    use sai_core_utils::{poseidon_hash_three, poseidon_hash_two};
    use sai_ownable::OwnableTrait;
    use sai_token::erc721::erc721_owner_of;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ClassHash, ContractAddress, get_block_timestamp, get_caller_address};
    use crate::table::{ArcadeRoundTable, AttemptRoundTrait, CombatTable};
    use super::{ArcadeActionResult, errors};

    #[storage]
    pub struct Storage {
        pub attempts: Map<felt252, AttemptNode>,
        pub max_respawns: u32,
        pub time_limit: u64,
        pub health_regen_percent: u8,
        pub current_attempt: Map<felt252, felt252>,
        pub loadout_address: ContractAddress,
        pub orb_minter: IOrbMinterDispatcher,
        pub orb_address: ContractAddress,
        pub max_orb_uses: u32,
        pub credit_address: ContractAddress,
        pub credit_cost: u128,
        pub energy_cost: u64,
        pub combat_class_hash: ClassHash,
        pub stage_reward_rates: Map<u32, OrbDropRates>,
        pub challenge_drop_rate: OrbDropRates,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {}

    #[embeddable_as(ArcadeSettingsImpl)]
    impl IArcadeImpl<
        TContractState,
        +HasComponent<TContractState>,
        +HasVrfComponent<TContractState>,
        +OwnableTrait<TContractState>,
    > of IArcadeSetup<ComponentState<TContractState>> {
        fn energy_cost(self: @ComponentState<TContractState>) -> u64 {
            self.energy_cost.read()
        }

        fn credit_cost(self: @ComponentState<TContractState>) -> u128 {
            self.credit_cost.read()
        }

        fn max_respawns(self: @ComponentState<TContractState>) -> u32 {
            self.max_respawns.read()
        }

        fn time_limit(self: @ComponentState<TContractState>) -> u64 {
            self.time_limit.read()
        }

        fn health_regen_percent(self: @ComponentState<TContractState>) -> u8 {
            self.health_regen_percent.read()
        }

        fn credit_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.credit_address.read()
        }


        fn combat_class_hash(self: @ComponentState<TContractState>) -> ClassHash {
            self.combat_class_hash.read()
        }

        fn orb_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.orb_address.read()
        }

        fn orb_minter_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.orb_minter.read().contract_address
        }

        fn max_orb_uses(self: @ComponentState<TContractState>) -> u32 {
            self.max_orb_uses.read()
        }

        fn stage_drop_rates(self: @ComponentState<TContractState>, stage: u32) -> OrbDropRates {
            self.stage_reward_rates.read(stage)
        }

        fn challenge_drop_rate(self: @ComponentState<TContractState>) -> OrbDropRates {
            self.challenge_drop_rate.read()
        }


        fn set_max_respawns(ref self: ComponentState<TContractState>, max_respawns: u32) {
            self.get_contract().assert_caller_is_owner();
            self.max_respawns.write(max_respawns);
        }

        fn set_time_limit(ref self: ComponentState<TContractState>, time_limit: u64) {
            self.get_contract().assert_caller_is_owner();
            self.time_limit.write(time_limit);
        }
        fn set_health_regen_percent(
            ref self: ComponentState<TContractState>, health_regen_percent: u8,
        ) {
            self.get_contract().assert_caller_is_owner();
            assert(health_regen_percent <= 100, 'Health regen must be <= 100');
            self.health_regen_percent.write(health_regen_percent);
        }

        fn set_credit_address(
            ref self: ComponentState<TContractState>, contract_address: ContractAddress,
        ) {
            self.get_contract().assert_caller_is_owner();
            self.credit_address.write(contract_address);
        }

        fn set_cost(ref self: ComponentState<TContractState>, energy: u64, credit: u128) {
            self.get_contract().assert_caller_is_owner();
            self.energy_cost.write(energy);
            self.credit_cost.write(credit);
        }

        fn set_combat_class_hash(ref self: ComponentState<TContractState>, class_hash: ClassHash) {
            self.get_contract().assert_caller_is_owner();
            self.combat_class_hash.write(class_hash);
        }

        fn set_orb_address(
            ref self: ComponentState<TContractState>, contract_address: ContractAddress,
        ) {
            self.get_contract().assert_caller_is_owner();
            self.orb_address.write(contract_address);
        }

        fn set_orb_minter_address(
            ref self: ComponentState<TContractState>, contract_address: ContractAddress,
        ) {
            self.get_contract().assert_caller_is_owner();
            self.orb_minter.write(IOrbMinterDispatcher { contract_address });
        }

        fn set_max_orb_uses(ref self: ComponentState<TContractState>, max_uses: u32) {
            self.get_contract().assert_caller_is_owner();
            self.max_orb_uses.write(max_uses);
        }

        fn set_drop_rates(
            ref self: ComponentState<TContractState>,
            challenge_rates: OrbDropRates,
            stage_rates: Array<OrbDropRates>,
        ) {
            self.get_contract().assert_caller_is_owner();
            self.challenge_drop_rate.write(challenge_rates);
            for (i, rates) in stage_rates.into_iter().enumerate() {
                self.stage_reward_rates.write(i, rates);
            }
        }
    }

    mod internal_trait {
        use ba_combat::Move;
        use ba_utils::Randomness;
        use starknet::{ClassHash, ContractAddress};
        use crate::Opponent;
        use super::{ArcadeActionResult, ArcadeProgress, AttemptNodePath};

        pub trait ArcadeInternalTrait<TState> {
            fn init(
                ref self: TState,
                namespace: ByteArray,
                arcade_round_result_class_hash: ClassHash,
                action_address: ContractAddress,
                loadout_address: ContractAddress,
                orb_address: ContractAddress,
            );
            fn start_attempt(
                ref self: TState,
                collection_address: ContractAddress,
                token_id: u256,
                action_slots: Array<Array<felt252>>,
            ) -> (AttemptNodePath, felt252, ContractAddress);

            fn act_attempt(
                ref self: TState, attempt_id: felt252, action: Move,
            ) -> (AttemptNodePath, ArcadeActionResult, Randomness);

            fn respawn_attempt(
                ref self: TState, attempt_id: felt252,
            ) -> (AttemptNodePath, u32, u32);

            fn forfeit_attempt(ref self: TState, attempt_id: felt252);

            fn new_combat(
                ref self: TState,
                ref attempt_ptr: AttemptNodePath,
                attempt_id: felt252,
                combat_n: u32,
                stage: u32,
                opponent: Opponent,
                health: Option<u8>,
            );

            fn get_stage_reward(
                ref self: TState, player: ContractAddress, stage: u32, ref randomness: Randomness,
            );
            fn get_challenge_reward(
                ref self: TState, player: ContractAddress, ref randomness: Randomness,
            );

            fn set_phase(ref self: AttemptNodePath, attempt_id: felt252, phase: ArcadeProgress);
            fn set_loss(ref self: TState, ref attempt: AttemptNodePath, attempt_id: felt252);
            fn use_credit(ref self: TState, player: ContractAddress);
            fn consume_randomness(ref self: TState, salt: felt252) -> Randomness;
        }
    }


    pub impl ArcadeInternal<
        TContractState,
        const ATTEMPT_HASH: felt252,
        const COMBAT_HASH: felt252,
        const ROUND_HASH: felt252,
        const LAST_USED_ATTACK_HASH: felt252,
        +HasComponent<TContractState>,
        +HasVrfComponent<TContractState>,
        +Drop<TContractState>,
    > of internal_trait::ArcadeInternalTrait<ComponentState<TContractState>> {
        fn init(
            ref self: ComponentState<TContractState>,
            namespace: ByteArray,
            arcade_round_result_class_hash: ClassHash,
            action_address: ContractAddress,
            loadout_address: ContractAddress,
            orb_address: ContractAddress,
        ) {
            set_action_dispatcher_address(action_address);
            self.loadout_address.write(loadout_address);
            register_table_with_schema::<ArcadeAttemptTable>(namespace.clone(), "Attempt");
            register_table_with_schema::<CombatTable>(namespace.clone(), "Combat");
            register_table(namespace.clone(), "Round", arcade_round_result_class_hash);
            register_table_with_schema::<ActionLastUsed>(namespace, "ActionLastUsed");
        }

        fn start_attempt(
            ref self: ComponentState<TContractState>,
            collection_address: ContractAddress,
            token_id: u256,
            action_slots: Array<Array<felt252>>,
        ) -> (AttemptNodePath, felt252, ContractAddress) {
            let player = get_caller_address();
            Self::use_credit(ref self, player);

            let attempt_id = uuid();
            let mut attempt_ptr = self.attempts.entry(attempt_id);
            let player = get_caller_address();
            let token_hash = erc721_token_hash(collection_address, token_id);
            assert(self.current_attempt.read(token_hash).is_zero(), 'Token Already in Challenge');
            assert(erc721_owner_of(collection_address, token_id) == player, 'Not Token Owner');
            let loadout_address = self.loadout_address.read();
            attempt_ptr.orb_uses.write(self.max_orb_uses.read());
            let (attributes, action_ids) = get_loadout(
                loadout_address, collection_address, token_id, action_slots,
            );
            let expiry = get_block_timestamp() + self.time_limit.read();
            let health_regen = get_max_health_percent(
                attributes.vitality, self.health_regen_percent.read(),
            );
            let attempt = ArcadeAttemptTable {
                player,
                collection_address,
                token_id,
                expiry,
                attributes,
                actions: action_ids.span(),
                health_regen,
                respawns: 0,
                stage: 0,
                phase: ArcadeProgress::Active,
            };
            set_entity(ATTEMPT_HASH, attempt_id, @attempt);
            attempt_ptr
                .new_attempt(player, attributes, action_ids, token_hash, health_regen, expiry);
            (attempt_ptr, attempt_id, loadout_address)
        }

        fn act_attempt(
            ref self: ComponentState<TContractState>, attempt_id: felt252, action: Move,
        ) -> (AttemptNodePath, ArcadeActionResult, Randomness) {
            let mut attempt_ptr = self.attempts.entry(attempt_id);

            let stage = attempt_ptr.stage.read();
            let combat_n = stage + attempt_ptr.respawns.read();
            let combat_id: felt252 = attempt_id + (combat_n.into());

            let player = attempt_ptr.assert_caller_is_owner();
            assert(attempt_ptr.phase.read() == ArcadeProgress::Active, 'Game is not active');
            let action_dispatcher = get_action_dispatcher();
            let mut combat_node = attempt_ptr.combats.entry(combat_n);
            assert(combat_node.phase.read() == ArcadeProgress::Active, errors::NOT_ACTIVE);
            let round = combat_node.round.read();
            let mut randomness = Self::consume_randomness(
                ref self, poseidon_hash_three(attempt_id, combat_n, round),
            );

            let player_state_ptr = combat_node.player_state;
            let opponent_state_ptr = combat_node.opponent_state;
            let (action_id, check) = match action {
                Move::None => (0, ActionCheck::None),
                Move::Action(action_id) => (
                    action_id, ActionCheck::Cooldown(attempt_ptr.actions_available.read(action_id)),
                ),
                Move::Orb(orb_id) => {
                    let orb_uses = attempt_ptr.orb_uses.read();
                    let action = if orb_uses == 0 {
                        0
                    } else {
                        match self
                            .orb_address
                            .read()
                            .try_use_owners_charge_cost(attempt_ptr.player.read(), orb_id) {
                            Some(action) => {
                                attempt_ptr.orb_uses.write(orb_uses - 1);
                                action
                            },
                            None => 0,
                        }
                    };
                    (action, ActionCheck::None)
                },
            };

            let opponent_action = combat_node
                .get_opponent_action(action_dispatcher, round, ref randomness);
            let (result, mut randomness) = library_run_round(
                self.combat_class_hash.read(),
                combat_id,
                round,
                player_state_ptr.read(),
                opponent_state_ptr.read(),
                action_id,
                opponent_action,
                check,
                ActionCheck::None,
                action_dispatcher,
                randomness,
            );

            let mut result: ArcadeRoundTable = result.to_arcade_round(attempt_id, combat_n, action);
            player_state_ptr.write(result.player_state);
            opponent_state_ptr.write(result.opponent_state);
            if result.progress == ArcadeProgress::Active {
                combat_node.round.write(round + 1);
            } else {
                combat_node.phase.write(result.progress);
            }
            set_entity(ROUND_HASH, poseidon_hash_three(attempt_id, combat_n, round), @result);
            if let MoveResult::Action(action_id) = result.player_move && action_id.is_non_zero() {
                set_entity(
                    LAST_USED_ATTACK_HASH,
                    poseidon_hash_two(combat_id, action_id),
                    @ActionLastUsed {
                        action: action_id, attempt: attempt_id, combat: combat_n, round,
                    },
                );
            }
            (
                attempt_ptr,
                ArcadeActionResult {
                    player,
                    phase: result.progress,
                    stage,
                    combat_n,
                    health: result.player_state.health,
                },
                randomness,
            )
        }

        fn respawn_attempt(
            ref self: ComponentState<TContractState>, attempt_id: felt252,
        ) -> (AttemptNodePath, u32, u32) {
            let mut attempt_ptr = self.attempts.entry(attempt_id);

            attempt_ptr.assert_active();
            let player = attempt_ptr.assert_caller_is_owner();
            Self::use_credit(ref self, player);
            assert(attempt_ptr.is_not_expired(), 'Attempt Expired');
            let (stage, respawns) = (attempt_ptr.stage.read(), attempt_ptr.respawns.read() + 1);
            assert(respawns <= self.max_respawns.read(), 'Max Respawns Reached');

            let combat_n = stage + respawns;
            match attempt_ptr.combats.entry(combat_n).phase.read() {
                ArcadeProgress::None => { panic_with_const_felt252::<errors::NOT_ACTIVE>(); },
                ArcadeProgress::PlayerWon |
                ArcadeProgress::Active => {
                    panic_with_const_felt252::<errors::RESPAWN_WHEN_NOT_LOST>();
                },
                ArcadeProgress::PlayerLost => {},
            }

            attempt_ptr.respawns.write(respawns);
            set_member(
                ATTEMPT_HASH,
                selector!("respawns"),
                attempt_id,
                @attempt_ptr.respawns.write(respawns),
            );
            (attempt_ptr, combat_n, stage)
        }

        fn forfeit_attempt(ref self: ComponentState<TContractState>, attempt_id: felt252) {
            let mut attempt_ptr = self.attempts.entry(attempt_id);
            attempt_ptr.assert_caller_is_owner();
            assert(attempt_ptr.phase.read() == ArcadeProgress::Active, errors::NOT_ACTIVE);
            Self::set_loss(ref self, ref attempt_ptr, attempt_id);
        }

        fn set_phase(ref self: AttemptNodePath, attempt_id: felt252, phase: ArcadeProgress) {
            self.phase.write(phase);
            set_member(ATTEMPT_HASH, selector!("phase"), attempt_id, @phase);
        }

        fn set_loss(
            ref self: ComponentState<TContractState>,
            ref attempt: AttemptNodePath,
            attempt_id: felt252,
        ) {
            Self::set_phase(ref attempt, attempt_id, ArcadeProgress::PlayerLost);
            let token_hash = attempt.token_hash.read();
            assert(self.current_attempt.read(token_hash) == attempt_id, 'Token not in Challenge');
            self.current_attempt.write(token_hash, 0x0);
        }

        fn new_combat(
            ref self: ComponentState<TContractState>,
            ref attempt_ptr: AttemptNodePath,
            attempt_id: felt252,
            combat_n: u32,
            stage: u32,
            opponent: Opponent,
            health: Option<u8>,
        ) {
            let mut combat = attempt_ptr.combats.entry(combat_n);
            let mut player_state: CombatantState = attempt_ptr.attributes.read().into();
            if let Some(health) = health {
                player_state.set_and_regen_health(health, attempt_ptr.health_regen.read());
            }
            let opponent_state: CombatantState = opponent.attributes.into();
            combat.create_combat(player_state, opponent_state, opponent.actions);
            set_entity(
                COMBAT_HASH,
                poseidon_hash_two(attempt_id, combat_n),
                @CombatTable {
                    attempt: attempt_id,
                    combat: combat_n,
                    stage,
                    starting_player_health: player_state.health,
                    starting_opponent_attributes: opponent.attributes,
                },
            );
        }

        fn use_credit(ref self: ComponentState<TContractState>, player: ContractAddress) {
            arena_credit_consume(
                self.credit_address.read(),
                player,
                self.energy_cost.read(),
                self.credit_cost.read(),
            );
        }

        fn consume_randomness(
            ref self: ComponentState<TContractState>, salt: felt252,
        ) -> Randomness {
            let mut contract = self.get_contract_mut();
            let mut component = HasVrfComponent::get_component_mut(ref contract);

            component.get_salt_randomness(salt)
        }

        fn get_stage_reward(
            ref self: ComponentState<TContractState>,
            player: ContractAddress,
            stage: u32,
            ref randomness: Randomness,
        ) {
            let drop_rates = self.stage_reward_rates.read(stage);
            self.orb_minter.read().roll(player, drop_rates, randomness.get_u64());
        }

        fn get_challenge_reward(
            ref self: ComponentState<TContractState>,
            player: ContractAddress,
            ref randomness: Randomness,
        ) {
            let drop_rates = self.challenge_drop_rate.read();
            self.orb_minter.read().roll(player, drop_rates, randomness.get_u64());
        }
    }
}
