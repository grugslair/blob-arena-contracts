use ba_blobert::Seed;
use ba_loadout::ability::Abilities;
use ba_loadout::attack::IdTagAttack;
use starknet::ContractAddress;


#[derive(Drop, Serde, starknet::Store)]
struct Opponent {
    abilities: Abilities,
    attacks: [felt252; 4],
}

#[derive(Drop, Serde, Introspect)]
struct OpponentTable {
    attributes: Seed,
    abilities: Abilities,
    attacks: Span<felt252>,
}


#[derive(Drop, Serde)]
struct OpponentInput {
    attributes: Seed,
    abilities: Abilities,
    attacks: [IdTagAttack; 4],
}

mod errors {
    pub const RESPAWN_WHEN_NOT_LOST: felt252 = 'Cannot respawn, player not lost';
    pub const NOT_ACTIVE: felt252 = 'Combat is not active';
    pub const MAX_RESPAWNS_REACHED: felt252 = 'Max respawns reached';
}

#[starknet::interface]
trait IAmmaArcade<TState> {
    fn start(
        ref self: TState,
        collection_address: ContractAddress,
        token_id: u256,
        attack_slots: Array<Array<felt252>>,
    ) -> felt252;
    fn attack(ref self: TState, attempt_id: felt252, attack_id: felt252);
    fn respawn(ref self: TState, attempt_id: felt252);
    fn forfeit(ref self: TState, attempt_id: felt252);
}

#[starknet::interface]
trait IAmmaArcadeAdmin<TState> {
    fn set_gen_stages(ref self: TState, gen_stages: u32);
    fn set_max_respawns(ref self: TState, max_respawns: u32);
    fn set_time_limit(ref self: TState, time_limit: u64);
    fn set_health_regen_permille(ref self: TState, health_regen_permille: u32);
}

#[starknet::contract]
mod amma_arcade {
    use core::cmp::min;
use ba_arcade::component::{ArcadePhase, AttemptNode, AttemptNodePath, AttemptNodeTrait};
    use ba_arcade::table::{ArcadeAttempt, ArcadeRound, AttackLastUsed};
    use ba_combat::CombatantState;
    use ba_loadout::ability::Abilities;
    use ba_loadout::attack::{
        IAttackAdminDispatcher, IAttackAdminDispatcherTrait, IAttackDispatcher,
    };
    use ba_loadout::get_loadout;
    use ba_utils::{erc721_token_hash, uuid, UpdateHashToU128, SeedProbability};
    use beacon_library::{ToriiTable, register_table_with_schema};
    use core::num::traits::Zero;
    use core::panic_with_const_felt252;
    use core::poseidon::poseidon_hash_span;
    use sai_ownable::{OwnableTrait, ownable_component};
    use sai_token::erc721::erc721_owner_of;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use super::{IAmmaArcade, IAmmaArcadeAdmin, errors};


    component!(path: ownable_component, storage: ownable, event: OwnableEvents);


    const ROUND_HASH: felt252 = bytearrays_hash!("amma_arcade", "ArcadeRound");
    const ATTEMPT_HASH: felt252 = bytearrays_hash!("amma_arcade", "ArcadeAttempt");
    const LAST_USED_ATTACK_HASH: felt252 = bytearrays_hash!("amma_arcade", "AttackLastUsed");
    const OPPONENT_HASH: felt252 = bytearrays_hash!("amma_arcade", "Opponent");

    impl RoundTable = ToriiTable<ROUND_HASH>;
    impl AttemptTable = ToriiTable<ATTEMPT_HASH>;
    impl LastUsedAttackTable = ToriiTable<LAST_USED_ATTACK_HASH>;
    impl OpponentTable = ToriiTable<OPPONENT_HASH>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: ownable_component::Storage,
        attempts: Map<felt252, AttemptNode>,
        gen_stages: u32,
        opponents: Map<felt252, u32>,
        max_respawns: u32,
        time_limit: u64,
        health_regen_permille: u32,
        current_attempt: Map<felt252, felt252>,
        attack_address: ContractAddress,
        loadout_address: ContractAddress,
        collectable_address: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvents: ownable_component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        attack_address: ContractAddress,
        loadout_address: ContractAddress,
        collectable_address: ContractAddress,
    ) {
        self.grant_owner(owner);
        register_table_with_schema::<ArcadeRound>("amma_arcade", "ArcadeRound");
        register_table_with_schema::<ArcadeAttempt>("amma_arcade", "ArcadeAttempt");
        register_table_with_schema::<AttackLastUsed>("amma_arcade", "AttackLastUsed");
        register_table_with_schema::<super::OpponentTable>("amma_arcade", "Opponent");
        self.loadout_address.write(loadout_address);
        self.attack_address.write(attack_address);
        self.collectable_address.write(collectable_address);
    }

    #[abi(embed_v0)]
    impl IOwnableImpl = ownable_component::OwnableImpl<ContractState>;

    #[abi(embed_v0)]
    impl IAmmaArcadeImpl of IAmmaArcade<ContractState> {
        fn start(
            ref self: ContractState,
            collection_address: ContractAddress,
            token_id: u256,
            attack_slots: Array<Array<felt252>>,
        ) -> felt252 {
            let attempt_id = uuid();
            let mut attempt_ptr = self.attempts.entry(attempt_id);
            let player = get_caller_address();
            let token_hash = erc721_token_hash(collection_address, token_id);
            assert(self.current_attempt.read(token_hash).is_zero(), 'Token Already in Challenge');
            assert(erc721_owner_of(collection_address, token_id) == player, 'Not Token Owner');
            let (abilities, attack_ids) = get_loadout(
                self.loadout_address.read(), collection_address, token_id, attack_slots,
            );
            let expiry = get_block_timestamp() + self.time_limit.read();

            AttemptTable::set_entity(
                attempt_id,
                @ArcadeAttempt {
                    player,
                    collection_address,
                    token_id,
                    expiry,
                    abilities,
                    attacks: attack_ids.span(),
                    respawns: 0,
                    stage: 0,
                    phase: ArcadePhase::Active,
                },
            );

            attempt_ptr.new_attempt(player, abilities, attack_ids, token_hash, expiry);
            self.new_combat(ref attempt_ptr, attempt_id, 0, 0, None);
            attempt_id
        }

        fn attack(ref self: ContractState, attempt_id: felt252, attack_id: felt252) {
            let mut attempt_ptr = self.attempts.entry(attempt_id);
            let randomness = uuid();
            let stage = attempt_ptr.stage.read();
            let combat_n = stage + attempt_ptr.respawns.read();
            let result = attempt_ptr
                .attack::<
                    LAST_USED_ATTACK_HASH, ROUND_HASH,
                >(self.attack_dispatcher(), attempt_id, combat_n, attack_id, randomness);
            if result.phase == ArcadePhase::PlayerWon {
                let next_stage = stage + 1;
                if next_stage == self.gen_stages.read() + 1 {
                    attempt_ptr.set_phase(attempt_id, ArcadePhase::PlayerWon);
                } else if attempt_ptr.is_not_expired() {
                    if next_stage == self.gen_stages.read() {
                        let boss= randomness.update_to_u128('boss').get_final_value()
                    } else {

                    }
                    attempt_ptr.stage.write(next_stage);
                    let health = *result.states.at(0).health;
                    self.new_combat(ref attempt_ptr, attempt_id, combat_n + 1, next_stage, Some(health));
                } else {
                    self.set_loss(ref attempt_ptr, attempt_id);
                }
            }
        }

        fn respawn(ref self: ContractState, attempt_id: felt252) {
            let mut attempt_ptr = self.attempts.entry(attempt_id);

            attempt_ptr.assert_active();
            attempt_ptr.assert_caller_is_owner();
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
            self.new_combat(ref attempt_ptr, attempt_id, combat_n + 1, stage, None);
            attempt_ptr.respawns.write(respawns);
            AttemptTable::set_member(
                selector!("respawns"), attempt_id, @attempt_ptr.respawns.write(respawns),
            );
        }

        fn forfeit(ref self: ContractState, attempt_id: felt252) {
            let mut attempt_ptr = self.attempts.entry(attempt_id);
            attempt_ptr.assert_caller_is_owner();
            assert(attempt_ptr.phase.read() == ArcadePhase::Active, errors::NOT_ACTIVE);
            self.set_loss(ref attempt_ptr, attempt_id);
        }
    }

    #[abi(embed_v0)]
    impl IAmmaArcadeAdminImpl of IAmmaArcadeAdmin<ContractState> {
        fn set_gen_stages(ref self: ContractState, gen_stages: u32) {
            self.assert_caller_is_owner();
            self.gen_stages.write(gen_stages);
        }

        fn set_max_respawns(ref self: ContractState, max_respawns: u32) {
            self.assert_caller_is_owner();
            self.max_respawns.write(max_respawns);
        }

        fn set_time_limit(ref self: ContractState, time_limit: u64) {
            self.assert_caller_is_owner();
            self.time_limit.write(time_limit);
        }
        fn set_health_regen_permille(ref self: ContractState, health_regen_permille: u32) {
            self.assert_caller_is_owner();
            assert(health_regen_permille <= 1000, 'Health regen must be <= 1000');
            self.health_regen_permille.write(health_regen_permille);
        }
    }


    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn new_combat(
            ref self: ContractState,
            ref attempt_ptr: AttemptNodePath,
            attempt_id: felt252,
            combat_n: u32,
            stage: u32,
            health: Option<u32>,
        ) {
            let mut combat = attempt_ptr.combats.entry(combat_n);
            let opponent = 
            let mut player_state: CombatantState = attempt_ptr.abilities.read().into();
            if let Some(health) = health {
                let new_health = health + (health * self.health_regen_permille.read()) / 1000;
                player_state.health = min(player_state.health, new_health);
            }
            let usable_attacks = opponent.attacks.span();
            let opponent_state: CombatantState = opponent.abilities.into();
            combat.create_combat(player_state, opponent_state, usable_attacks);
            RoundTable::set_entity(
                poseidon_hash_span([attempt_id, combat_n.into(), 0.into()].span()),
                @ArcadeRound {
                    attempt: attempt_id,
                    combat: combat_n,
                    round: 0,
                    states: [player_state, opponent_state].span(),
                    switch_order: false,
                    outcomes: [].span(),
                    phase: ArcadePhase::Active,
                },
            );
        }

        fn set_phase(ref self: AttemptNodePath, attempt_id: felt252, phase: ArcadePhase) {
            self.phase.write(phase);
            AttemptTable::set_member(selector!("phase"), attempt_id, @phase);
        }

        fn set_loss(ref self: ContractState, ref attempt: AttemptNodePath, attempt_id: felt252) {
            attempt.set_phase(attempt_id, ArcadePhase::PlayerLost);
            let token_hash = attempt.token_hash.read();
            assert(self.current_attempt.read(token_hash) == attempt_id, 'Token not in Challenge');
            self.current_attempt.write(token_hash, 0x0);
        }

        fn attack_dispatcher(ref self: ContractState) -> IAttackDispatcher {
            IAttackDispatcher { contract_address: self.attack_address.read() }
        }

        fn attack_admin_dispatcher(ref self: ContractState) -> IAttackAdminDispatcher {
            IAttackAdminDispatcher { contract_address: self.attack_address.read() }
        }
    }
}
