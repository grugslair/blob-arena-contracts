use ba_loadout::ability::Abilities;
use crate::attempt::ArcadePhase;

mod errors {
    pub const RESPAWN_WHEN_NOT_LOST: felt252 = 'Cannot respawn, player not lost';
    pub const NOT_ACTIVE: felt252 = 'Combat is not active';
    pub const MAX_RESPAWNS_REACHED: felt252 = 'Max respawns reached';
}

#[derive(Drop)]
pub struct Opponent {
    pub abilities: Abilities,
    pub attacks: Span<felt252>,
}

#[derive(Drop)]
pub struct ArcadeAttackResult {
    pub phase: ArcadePhase,
    pub stage: u32,
    pub combat_n: u32,
    pub health: u16,
}

#[starknet::component]
pub mod arcade_component {
    use ba_arcade::IArcadeSetup;
    use ba_arcade::attempt::{ArcadePhase, AttemptNode, AttemptNodePath, AttemptNodeTrait};
    use ba_arcade::table::{ArcadeAttempt, ArcadeRound, AttackLastUsed};
    use ba_combat::combat::run_round;
    use ba_combat::{CombatantState, Player};
    use ba_credit::arena_credit_consume;
    use ba_loadout::ability::AbilitiesTrait;
    use ba_loadout::attack::IAttackDispatcher;
    use ba_loadout::get_loadout;
    use ba_utils::vrf::consume_randomness;
    use ba_utils::{Randomness, erc721_token_hash, uuid};
    use beacon_library::{ToriiTable, register_table_with_schema, set_entity, set_member};
    use core::cmp::min;
    use core::num::traits::Zero;
    use core::panic_with_const_felt252;
    use core::poseidon::poseidon_hash_span;
    use sai_core_utils::{poseidon_hash_three, poseidon_hash_two};
    use sai_ownable::OwnableTrait;
    use sai_token::erc721::erc721_owner_of;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use crate::table::AttemptRoundTrait;
    use super::{ArcadeAttackResult, Opponent, errors};


    #[storage]
    pub struct Storage {
        pub attempts: Map<felt252, AttemptNode>,
        pub max_respawns: u32,
        pub time_limit: u64,
        pub health_regen_permille: u16,
        pub current_attempt: Map<felt252, felt252>,
        pub attack_address: ContractAddress,
        pub loadout_address: ContractAddress,
        pub credit_address: ContractAddress,
        pub credit_cost: u128,
        pub energy_cost: u64,
        pub vrf_address: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {}

    #[embeddable_as(ArcadeSettingsImpl)]
    impl IArcadeImpl<
        TContractState, +HasComponent<TContractState>, +OwnableTrait<TContractState>,
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

        fn health_regen_permille(self: @ComponentState<TContractState>) -> u16 {
            self.health_regen_permille.read()
        }

        fn credit_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.credit_address.read()
        }

        fn vrf_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.vrf_address.read()
        }

        fn set_max_respawns(ref self: ComponentState<TContractState>, max_respawns: u32) {
            self.get_contract().assert_caller_is_owner();
            self.max_respawns.write(max_respawns);
        }

        fn set_time_limit(ref self: ComponentState<TContractState>, time_limit: u64) {
            self.get_contract().assert_caller_is_owner();
            self.time_limit.write(time_limit);
        }
        fn set_health_regen_permille(
            ref self: ComponentState<TContractState>, health_regen_permille: u16,
        ) {
            self.get_contract().assert_caller_is_owner();
            assert(health_regen_permille <= 1000, 'Health regen must be <= 1000');
            self.health_regen_permille.write(health_regen_permille);
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

        fn set_vrf_address(
            ref self: ComponentState<TContractState>, contract_address: ContractAddress,
        ) {
            self.get_contract().assert_caller_is_owner();
            self.vrf_address.write(contract_address);
        }
    }

    mod internal_trait {
        use ba_utils::Randomness;
        use starknet::ContractAddress;
        use crate::Opponent;
        use super::{ArcadeAttackResult, ArcadePhase, AttemptNodePath};

        pub trait ArcadeInternalTrait<TState> {
            fn init(
                ref self: TState,
                namespace: ByteArray,
                attack_address: ContractAddress,
                loadout_address: ContractAddress,
                credit_address: ContractAddress,
                vrf_address: ContractAddress,
            );
            fn start_attempt(
                ref self: TState,
                collection_address: ContractAddress,
                token_id: u256,
                attack_slots: Array<Array<felt252>>,
            ) -> (AttemptNodePath, felt252, ContractAddress);

            fn attack_attempt(
                ref self: TState, attempt_id: felt252, attack_id: felt252,
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
                opponent: Opponent,
                health: Option<u16>,
            );

            fn set_phase(ref self: AttemptNodePath, attempt_id: felt252, phase: ArcadePhase);
            fn set_loss(ref self: TState, ref attempt: AttemptNodePath, attempt_id: felt252);
            fn use_credit(ref self: TState, player: ContractAddress);
            fn consume_randomness(ref self: TState, salt: felt252) -> Randomness;
        }
    }


    pub impl ArcadeInternal<
        TContractState,
        const ATTEMPT_HASH: felt252,
        const ROUND_HASH: felt252,
        const LAST_USED_ATTACK_HASH: felt252,
    > of internal_trait::ArcadeInternalTrait<ComponentState<TContractState>> {
        fn init(
            ref self: ComponentState<TContractState>,
            namespace: ByteArray,
            attack_address: ContractAddress,
            loadout_address: ContractAddress,
            credit_address: ContractAddress,
            vrf_address: ContractAddress,
        ) {
            self.attack_address.write(attack_address);
            self.loadout_address.write(loadout_address);
            self.credit_address.write(credit_address);
            self.vrf_address.write(vrf_address);
            register_table_with_schema::<ArcadeAttempt>(namespace.clone(), "ArcadeAttempt");
            register_table_with_schema::<ArcadeRound>(namespace.clone(), "ArcadeRound");
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

            let (abilities, attack_ids) = get_loadout(
                loadout_address, collection_address, token_id, attack_slots,
            );
            let expiry = get_block_timestamp() + self.time_limit.read();
            let health_regen = abilities.max_health_permille(self.health_regen_permille.read());
            let attempt = ArcadeAttempt {
                player,
                collection_address,
                token_id,
                expiry,
                abilities,
                attacks: attack_ids.span(),
                health_regen,
                respawns: 0,
                stage: 0,
                phase: ArcadePhase::Active,
            };
            set_entity(ATTEMPT_HASH, attempt_id, @attempt);
            attempt_ptr
                .new_attempt(player, abilities, attack_ids, token_hash, health_regen, expiry);
            (attempt_ptr, attempt_id, loadout_address)
        }

        fn attack_attempt(
            ref self: ComponentState<TContractState>, attempt_id: felt252, attack_id: felt252,
        ) -> (AttemptNodePath, ArcadeAttackResult, Randomness) {
            let mut attempt_ptr = self.attempts.entry(attempt_id);

            let stage = attempt_ptr.stage.read();
            let combat_n = stage + attempt_ptr.respawns.read();

            attempt_ptr.assert_caller_is_owner();
            assert(attempt_ptr.phase.read() == ArcadePhase::Active, 'Game is not active');
            let attack_dispatcher = IAttackDispatcher {
                contract_address: self.attack_address.read(),
            };
            let mut combat = attempt_ptr.combats.entry(combat_n);
            let round = combat.round.read();
            let mut randomness = consume_randomness(
                self.vrf_address.read(), poseidon_hash_three(attempt_id, combat_n, round),
            );

            let opponent_attack = combat
                .get_opponent_attack(attack_dispatcher, round, ref randomness);
            let player_attack = match attempt_ptr.attacks_available.read(attack_id) {
                false => 0x0,
                true => combat.player_attack_cooldown(attack_dispatcher, attack_id, round),
            };
            let result = run_round(
                combat.player_state.read(),
                combat.opponent_state.read(),
                attack_dispatcher,
                player_attack,
                opponent_attack,
                round,
                ref randomness,
            )
                .to_round(attempt_id, combat_n);
            combat.player_state.write(*result.states.at(0));
            combat.opponent_state.write(*result.states.at(1));
            if result.phase == ArcadePhase::Active {
                combat.round.write(round + 1);
            } else {
                combat.phase.write(result.phase);
            }
            set_entity(ROUND_HASH, poseidon_hash_three(attempt_id, combat_n, round), @result);
            if player_attack.is_non_zero() {
                set_entity(
                    LAST_USED_ATTACK_HASH,
                    poseidon_hash_two(attempt_id, attack_id),
                    @AttackLastUsed {
                        attack: attack_id, attempt: attempt_id, combat: combat_n, round,
                    },
                );
            }
            (
                attempt_ptr,
                ArcadeAttackResult {
                    phase: result.phase, stage, combat_n, health: *result.states.at(0).health,
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
                ArcadePhase::None => { panic_with_const_felt252::<errors::NOT_ACTIVE>(); },
                ArcadePhase::PlayerWon |
                ArcadePhase::Active => {
                    panic_with_const_felt252::<errors::RESPAWN_WHEN_NOT_LOST>();
                },
                ArcadePhase::PlayerLost => {},
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
            assert(attempt_ptr.phase.read() == ArcadePhase::Active, errors::NOT_ACTIVE);
            Self::set_loss(ref self, ref attempt_ptr, attempt_id);
        }

        fn set_phase(ref self: AttemptNodePath, attempt_id: felt252, phase: ArcadePhase) {
            self.phase.write(phase);
            set_member(ATTEMPT_HASH, selector!("phase"), attempt_id, @phase);
        }

        fn set_loss(
            ref self: ComponentState<TContractState>,
            ref attempt: AttemptNodePath,
            attempt_id: felt252,
        ) {
            Self::set_phase(ref attempt, attempt_id, ArcadePhase::PlayerLost);
            let token_hash = attempt.token_hash.read();
            assert(self.current_attempt.read(token_hash) == attempt_id, 'Token not in Challenge');
            self.current_attempt.write(token_hash, 0x0);
        }

        fn new_combat(
            ref self: ComponentState<TContractState>,
            ref attempt_ptr: AttemptNodePath,
            attempt_id: felt252,
            combat_n: u32,
            opponent: Opponent,
            health: Option<u16>,
        ) {
            let mut combat = attempt_ptr.combats.entry(combat_n);
            let mut player_state: CombatantState = attempt_ptr.abilities.read().into();
            if let Some(health) = health {
                player_state
                    .health = min(player_state.health, health + attempt_ptr.health_regen.read());
            }
            let usable_attacks = opponent.attacks;
            let opponent_state: CombatantState = opponent.abilities.into();
            combat.create_combat(player_state, opponent_state, usable_attacks);
            set_entity(
                ROUND_HASH,
                poseidon_hash_span([attempt_id, combat_n.into()].span()),
                @ArcadeRound {
                    attempt: attempt_id,
                    combat: combat_n,
                    round: 0,
                    attacks: [].span(),
                    states: [player_state, opponent_state].span(),
                    first: Player::Player1,
                    outcomes: [].span(),
                    phase: ArcadePhase::Active,
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
            consume_randomness(self.vrf_address.read(), salt)
        }
    }
}
