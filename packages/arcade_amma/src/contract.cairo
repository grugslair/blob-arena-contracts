use ba_loadout::ability::Abilities;
use starknet::ContractAddress;

mod errors {
    pub const RESPAWN_WHEN_NOT_LOST: felt252 = 'Cannot respawn, player not lost';
    pub const NOT_ACTIVE: felt252 = 'Combat is not active';
    pub const MAX_RESPAWNS_REACHED: felt252 = 'Max respawns reached';
}

#[derive(Drop)]
struct Opponent {
    abilities: Abilities,
    attacks: Array<felt252>,
}

#[starknet::interface]
trait IArcadeAmmaAdmin<TState> {
    fn gen_stages(self: @TState) -> u32;
    fn set_gen_stages(ref self: TState, gen_stages: u32);
}

#[starknet::contract]
mod arcade_amma {
    use ba_arcade::component::{ArcadePhase, AttemptNode, AttemptNodePath, AttemptNodeTrait};
    use ba_arcade::table::{ArcadeAttempt, ArcadeRound, AttackLastUsed};
    use ba_combat::CombatantState;
    use ba_loadout::ability::AbilitiesTrait;
    use ba_loadout::amma_contract::{
        get_fighter_count, get_fighter_gen_loadout, get_fighter_loadout,
    };
    use ba_loadout::attack::{IAttackAdminDispatcher, IAttackDispatcher};
    use ba_loadout::get_loadout;
    use ba_utils::{SeedProbability, erc721_token_hash, felt252_to_u128, uuid};
    use beacon_library::{ToriiTable, register_table_with_schema};
    use core::cmp::min;
    use core::num::traits::Zero;
    use core::panic_with_const_felt252;
    use core::poseidon::poseidon_hash_span;
    use sai_core_utils::poseidon_hash_two;
    use sai_ownable::{OwnableTrait, ownable_component};
    use sai_return::emit_return;
    use sai_token::erc721::erc721_owner_of;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use crate::systems::{attack_slots, get_stage_stats, random_selection};
    use super::{IArcadeAmma, IArcadeAmmaAdmin, Opponent, errors};


    component!(path: ownable_component, storage: ownable, event: OwnableEvents);


    const ROUND_HASH: felt252 = bytearrays_hash!("arcade_amma", "ArcadeRound");
    const ATTEMPT_HASH: felt252 = bytearrays_hash!("arcade_amma", "ArcadeAttempt");
    const LAST_USED_ATTACK_HASH: felt252 = bytearrays_hash!("arcade_amma", "AttackLastUsed");
    const OPPONENTS_HASH: felt252 = bytearrays_hash!("arcade_amma", "Opponents");

    impl RoundTable = ToriiTable<ROUND_HASH>;
    impl AttemptTable = ToriiTable<ATTEMPT_HASH>;
    impl LastUsedAttackTable = ToriiTable<LAST_USED_ATTACK_HASH>;
    impl OpponentsTable = ToriiTable<OPPONENTS_HASH>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: ownable_component::Storage,
        attempts: Map<felt252, AttemptNode>,
        gen_stages: u32,
        opponents: Map<felt252, u32>,
        bosses: Map<felt252, u32>,
        attempt_gen_stages: Map<felt252, u32>,
        max_respawns: u32,
        time_limit: u64,
        health_regen_permille: u32,
        current_attempt: Map<felt252, felt252>,
        attack_address: ContractAddress,
        loadout_address: ContractAddress,
        collectable_address: ContractAddress,
        fuel_contract: ContractAddress,
        credits_cost: u128,
        fuel_cost: u64,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvents: ownable_component::Event,
    }

    #[derive(Drop, Serde, Introspect)]
    struct Opponents {
        generated: Array<u32>,
        boss: u32,
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
        register_table_with_schema::<ArcadeRound>("arcade_amma", "ArcadeRound");
        register_table_with_schema::<ArcadeAttempt>("arcade_amma", "ArcadeAttempt");
        register_table_with_schema::<AttackLastUsed>("arcade_amma", "AttackLastUsed");
        register_table_with_schema::<Opponents>("arcade_amma", "Opponents");
        self.loadout_address.write(loadout_address);
        self.attack_address.write(attack_address);
        self.collectable_address.write(collectable_address);
    }

    #[abi(embed_v0)]
    impl IOwnableImpl = ownable_component::OwnableImpl<ContractState>;

    #[abi(embed_v0)]
    impl IArcadeAmmaImpl of IArcadeAmma<ContractState> {
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
            let loadout_address = self.loadout_address.read();

            let (abilities, attack_ids) = get_loadout(
                loadout_address, collection_address, token_id, attack_slots,
            );
            let expiry = get_block_timestamp() + self.time_limit.read();
            let health_regen = abilities.max_health_permille(self.health_regen_permille.read());
            AttemptTable::set_entity(
                attempt_id,
                @ArcadeAttempt {
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
                },
            );
            attempt_ptr
                .new_attempt(player, abilities, attack_ids, token_hash, health_regen, expiry);

            let opponents = random_selection(
                attempt_id, get_fighter_count(loadout_address), self.gen_stages.read(),
            );
            self
                .new_combat(
                    ref attempt_ptr,
                    attempt_id,
                    0,
                    self.gen_opponent(loadout_address, *opponents[0], 0),
                    None,
                );
            OpponentsTable::set_entity(attempt_id, @(opponents.span(), 0));
            for (i, opponent) in opponents.into_iter().enumerate() {
                self.opponents.write(poseidon_hash_two(attempt_id, i), opponent);
            }

            emit_return(attempt_id)
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
                    attempt_ptr.stage.write(next_stage);
                    let health = *result.states.at(0).health;
                    let loadout_address = self.loadout_address.read();
                    let opponent = match next_stage == self.gen_stages.read() {
                        true => self.gen_boss_opponent(attempt_id, randomness),
                        false => self.gen_opponent_stage(loadout_address, attempt_id, next_stage),
                    };
                    self
                        .new_combat(
                            ref attempt_ptr, attempt_id, combat_n + 1, opponent, Some(health),
                        );
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

            let opponent = match stage == self.gen_stages.read() {
                true => self.read_boss_opponent(attempt_id),
                false => self.gen_opponent_stage(self.loadout_address.read(), attempt_id, stage),
            };

            self.new_combat(ref attempt_ptr, attempt_id, combat_n + 1, opponent, None);
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
    impl IArcadeAmmaAdminImpl of IArcadeAmmaAdmin<ContractState> {
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
            opponent: Opponent,
            health: Option<u32>,
        ) {
            let mut combat = attempt_ptr.combats.entry(combat_n);
            let mut player_state: CombatantState = attempt_ptr.abilities.read().into();
            if let Some(health) = health {
                player_state
                    .health = min(player_state.health, health + attempt_ptr.health_regen.read());
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

        fn gen_opponent_stage(
            self: @ContractState, loadout_address: ContractAddress, attempt_id: felt252, stage: u32,
        ) -> Opponent {
            self
                .gen_opponent(
                    loadout_address,
                    self.opponents.read(poseidon_hash_two(attempt_id, stage)),
                    stage,
                )
        }

        fn gen_opponent(
            self: @ContractState, loadout_address: ContractAddress, fighter: u32, stage: u32,
        ) -> Opponent {
            let (gen_abilities, attacks) = get_fighter_gen_loadout(
                loadout_address, fighter, attack_slots(),
            );

            let abilities = get_stage_stats(stage, gen_abilities);
            Opponent { abilities, attacks }
        }

        fn gen_boss_opponent(
            ref self: ContractState, attempt_id: felt252, randomness: felt252,
        ) -> Opponent {
            let loadout_address = self.loadout_address.read();
            let count = get_fighter_count(loadout_address);
            let fighter: u32 = (felt252_to_u128(poseidon_hash_two(randomness, 'boss'))
                .get_final_value(count)
                + 1);
            OpponentsTable::set_member(selector!("boss"), attempt_id, @fighter);
            self.bosses.write(attempt_id, fighter);
            self.boss_opponent(loadout_address, fighter)
        }

        fn read_boss_opponent(self: @ContractState, attempt_id: felt252) -> Opponent {
            let fighter = self.bosses.read(attempt_id);
            self.boss_opponent(self.loadout_address.read(), fighter)
        }

        fn boss_opponent(
            self: @ContractState, loadout_address: ContractAddress, fighter: u32,
        ) -> Opponent {
            let (abilities, attacks) = get_fighter_loadout(
                loadout_address, fighter, attack_slots(),
            );
            Opponent { abilities, attacks }
        }
    }
}
