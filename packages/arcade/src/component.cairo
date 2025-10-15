use ba_loadout::Attributes;
use ba_utils::storage::{FeltArrayReadWrite, ShortArrayStore};
use crate::attempt::ArcadeProgress;

mod errors {
    pub const RESPAWN_WHEN_NOT_LOST: felt252 = 'Cannot respawn, player not lost';
    pub const NOT_ACTIVE: felt252 = 'Combat is not active';
    pub const MAX_RESPAWNS_REACHED: felt252 = 'Max respawns reached';
}

#[derive(Drop, starknet::Store)]
pub struct Opponent {
    pub attributes: Attributes,
    pub attacks: Array<felt252>,
}

#[derive(Drop)]
pub struct ArcadeAttackResult {
    pub phase: ArcadeProgress,
    pub stage: u32,
    pub combat_n: u32,
    pub health: u8,
}

#[starknet::component]
pub mod arcade_component {
    use ba_arcade::IArcadeSetup;
    use ba_arcade::attempt::{ArcadeProgress, AttemptNode, AttemptNodePath, AttemptNodeTrait};
    use ba_arcade::table::{ArcadeAttemptTable, AttackLastUsed};
    use ba_combat::combat::AttackCheck;
    use ba_combat::combatant::get_max_health_percent;
    use ba_combat::systems::{get_attack_dispatcher, set_attack_dispatcher_address};
    use ba_combat::{Action, CombatantState, library_run_round};
    use ba_credit::arena_credit_consume;
    use ba_loadout::get_loadout;
    use ba_orbs::OrbTrait;
    use ba_utils::vrf::{HasVrfComponent, VrfTrait};
    use ba_utils::{Randomness, erc721_token_hash, uuid};
    use beacon_library::{
        ToriiTable, register_table, register_table_with_schema, set_entity, set_member,
    };
    use core::cmp::min;
    use core::num::traits::{SaturatingAdd, Zero};
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
    use super::{ArcadeAttackResult, Opponent, errors};

    #[storage]
    pub struct Storage {
        pub attempts: Map<felt252, AttemptNode>,
        pub max_respawns: u32,
        pub time_limit: u64,
        pub health_regen_percent: u8,
        pub current_attempt: Map<felt252, felt252>,
        pub loadout_address: ContractAddress,
        pub orb_address: ContractAddress,
        pub credit_address: ContractAddress,
        pub credit_cost: u128,
        pub energy_cost: u64,
        pub combat_class_hash: ClassHash,
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
    }

    mod internal_trait {
        use ba_combat::Action;
        use ba_utils::Randomness;
        use starknet::{ClassHash, ContractAddress};
        use crate::Opponent;
        use super::{ArcadeAttackResult, ArcadeProgress, AttemptNodePath};

        pub trait ArcadeInternalTrait<TState> {
            fn init(
                ref self: TState,
                namespace: ByteArray,
                arcade_round_result_class_hash: ClassHash,
                attack_address: ContractAddress,
                loadout_address: ContractAddress,
            );
            fn start_attempt(
                ref self: TState,
                collection_address: ContractAddress,
                token_id: u256,
                attack_slots: Array<Array<felt252>>,
            ) -> (AttemptNodePath, felt252, ContractAddress);

            fn act_attempt(
                ref self: TState, attempt_id: felt252, action: Action,
            ) -> (AttemptNodePath, ArcadeAttackResult, Randomness);

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
            attack_address: ContractAddress,
            loadout_address: ContractAddress,
        ) {
            set_attack_dispatcher_address(attack_address);
            self.loadout_address.write(loadout_address);
            register_table_with_schema::<ArcadeAttemptTable>(namespace.clone(), "Attempt");
            register_table_with_schema::<CombatTable>(namespace.clone(), "Combat");
            register_table(namespace.clone(), "Round", arcade_round_result_class_hash);
            register_table_with_schema::<AttackLastUsed>(namespace, "AttackLastUsed");
        }

        fn start_attempt(
            ref self: ComponentState<TContractState>,
            collection_address: ContractAddress,
            token_id: u256,
            attack_slots: Array<Array<felt252>>,
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

            let (attributes, attack_ids) = get_loadout(
                loadout_address, collection_address, token_id, attack_slots,
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
                attacks: attack_ids.span(),
                health_regen,
                respawns: 0,
                stage: 0,
                phase: ArcadeProgress::Active,
            };
            set_entity(ATTEMPT_HASH, attempt_id, @attempt);
            attempt_ptr
                .new_attempt(player, attributes, attack_ids, token_hash, health_regen, expiry);
            (attempt_ptr, attempt_id, loadout_address)
        }

        fn act_attempt(
            ref self: ComponentState<TContractState>, attempt_id: felt252, action: Action,
        ) -> (AttemptNodePath, ArcadeAttackResult, Randomness) {
            let mut attempt_ptr = self.attempts.entry(attempt_id);

            let stage = attempt_ptr.stage.read();
            let combat_n = stage + attempt_ptr.respawns.read();
            let combat_id: felt252 = attempt_id + (combat_n.into());

            attempt_ptr.assert_caller_is_owner();
            assert(attempt_ptr.phase.read() == ArcadeProgress::Active, 'Game is not active');
            let attack_dispatcher = get_attack_dispatcher();
            let mut combat_node = attempt_ptr.combats.entry(combat_n);
            assert(combat_node.phase.read() == ArcadeProgress::Active, errors::NOT_ACTIVE);
            let round = combat_node.round.read();
            let mut randomness = Self::consume_randomness(
                ref self, poseidon_hash_three(attempt_id, combat_n, round),
            );

            let player_state_ptr = combat_node.player_state;
            let opponent_state_ptr = combat_node.opponent_state;

            let (attack_id, check) = match action {
                Action::None => (0, AttackCheck::None),
                Action::Attack(attack_id) => (
                    attack_id, AttackCheck::Cooldown(attempt_ptr.attacks_available.read(attack_id)),
                ),
                Action::Orb(orb_id) => (
                    self
                        .orb_address
                        .read()
                        .try_use_owners_charge_cost(
                            attempt_ptr.player.read(), orb_id.try_into().unwrap(),
                        )
                        .unwrap_or(0),
                    AttackCheck::None,
                ),
            };

            let opponent_attack = combat_node
                .get_opponent_attack(attack_dispatcher, round, ref randomness);
            let (result, mut randomness) = library_run_round(
                self.combat_class_hash.read(),
                combat_id,
                round,
                player_state_ptr.read(),
                opponent_state_ptr.read(),
                attack_id,
                opponent_attack,
                check,
                AttackCheck::None,
                attack_dispatcher,
                randomness,
            );

            let mut result: ArcadeRoundTable = result.to_arcade_round(attempt_id, combat_n);
            player_state_ptr.write(result.player_state);
            opponent_state_ptr.write(result.opponent_state);
            if result.progress == ArcadeProgress::Active {
                combat_node.round.write(round + 1);
            } else {
                combat_node.phase.write(result.progress);
            }
            set_entity(ROUND_HASH, poseidon_hash_three(attempt_id, combat_n, round), @result);
            if result.player_attack.is_non_zero() {
                set_entity(
                    LAST_USED_ATTACK_HASH,
                    poseidon_hash_two(combat_id, attack_id),
                    @AttackLastUsed {
                        attack: attack_id, attempt: attempt_id, combat: combat_n, round,
                    },
                );
            }
            (
                attempt_ptr,
                ArcadeAttackResult {
                    phase: result.progress, stage, combat_n, health: result.player_state.health,
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
                player_state
                    .health =
                        min(
                            health.saturating_add(attempt_ptr.health_regen.read()),
                            player_state.health,
                        );
            }
            let opponent_state: CombatantState = opponent.attributes.into();
            combat.create_combat(player_state, opponent_state, opponent.attacks);
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
    }
}
