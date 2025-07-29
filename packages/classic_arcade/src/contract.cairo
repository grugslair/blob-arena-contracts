use ba_loadout::ability::Abilities;
use starknet::ContractAddress;


#[derive(Drop, Serde, starknet::Store)]
struct Opponent {
    abilities: Abilities,
    attacks: [felt252; 4],
}
mod errors {
    pub const RESPAWN_WHEN_WON: felt252 = 'Cannot respawn when player won';
    pub const NOT_ACTIVE: felt252 = 'Combat is not active';
    pub const ATTEMPT_DOES_NOT_EXIST: felt252 = 'Attempt does not exist';
    pub const MAX_RESPAWNS_REACHED: felt252 = 'Max respawns reached';
    pub const NOT_CALLERS_GAME: felt252 = 'Not caller\'s game';
}

#[starknet::interface]
trait IClassicArcade<TState> {
    fn start(
        ref self: TState,
        loadout_address: ContractAddress,
        collection_address: ContractAddress,
        token_id: u256,
        attack_slots: Array<Array<felt252>>,
    ) -> felt252;
    fn attack(ref self: TState, attempt: felt252, attack: felt252);
    fn respawn(ref self: TState, attempt: felt252);
    fn forfeit(ref self: TState, attempt: felt252);
}

#[starknet::contract]
mod classic_arcade {
    use ba_arcade::component::{ArcadePhase, AttemptNode, AttemptNodePath, AttemptNodeTrait};
    use ba_arcade::table::{ArcadeAttempt, ArcadeRound, AttackLastUsed};
    use ba_combat::CombatantState;
    use ba_loadout::attack::IAttackDispatcher;
    use ba_loadout::{attack, get_loadout};
    use ba_utils::{erc721_token_hash, uuid};
    use beacon_library::{ToriiTable, register_table_with_schema};
    use core::num::traits::Zero;
    use core::panic_with_const_felt252;
    use core::poseidon::poseidon_hash_span;
    use sai_token::erc721::erc721_owner_of;
    use starknet::storage::{
        Map, Mutable, MutableVecTrait, PendingStoragePath, StorageMapReadAccess,
        StorageMapWriteAccess, StoragePath, StoragePathEntry, StoragePointerReadAccess,
        StoragePointerWriteAccess, Vec,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use super::{IClassicArcade, Opponent, errors};

    const ROUND_HASH: felt252 = bytearrays_hash!("classic_arcade", "Round");
    const ATTEMPT_HASH: felt252 = bytearrays_hash!("classic_arcade", "Attempt");
    const LAST_USED_ATTACK_HASH: felt252 = bytearrays_hash!("classic_arcade", "AttackLastUsed");

    impl RoundTable = ToriiTable<ROUND_HASH>;
    impl AttemptTable = ToriiTable<ATTEMPT_HASH>;
    impl LastUsedAttackTable = ToriiTable<LAST_USED_ATTACK_HASH>;

    #[storage]
    struct Storage {
        attack_dispatcher: IAttackDispatcher,
        attempts: Map<felt252, AttemptNode>,
        opponents: Map<u32, Opponent>,
        stages_len: u32,
        max_respawns: u32,
        time_limit: u64,
        current_attempt: Map<felt252, felt252>,
        loadouts_allowed: Map<ContractAddress, bool>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.grant_owner(owner);
        register_table_with_schema::<ArcadeRound>("classic_arcade", "Attempt");
        register_table_with_schema::<ArcadeAttempt>("classic_arcade", "Round");
        register_table_with_schema::<AttackLastUsed>("classic_arcade", "AttackLastUsed");
    }

    impl IClassicArcadeImpl of IClassicArcade<ContractState> {
        fn start(
            ref self: ContractState,
            loadout_address: ContractAddress,
            collection_address: ContractAddress,
            token_id: u256,
            attack_slots: Array<Array<felt252>>,
        ) -> felt252 {
            let attempt_id = uuid();
            let mut attempt_ptr = self.attempts.entry(attempt_id);
            let player = attempt_ptr.assert_caller_is_owner();
            let token_hash = erc721_token_hash(collection_address, token_id);
            assert(self.current_attempt.read(token_hash).is_zero(), 'Token ALready in Challenge');
            assert(erc721_owner_of(collection_address, token_id) == player, 'Not Token Owner');

            let (abilities, attack_id) = get_loadout(
                loadout_address, collection_address, token_id, attack_slots,
            );
            let expiry = get_block_timestamp() + self.time_limit.read();

            AttemptTable::set_entity(
                attempt_id,
                @ArcadeAttempt {
                    player,
                    loadout: loadout_address,
                    collection_address,
                    token_id,
                    expiry,
                    abilities,
                    attacks: attack_id.span(),
                    respawns: 0,
                    stage: 0,
                    phase: ArcadePhase::Active,
                },
            );

            attempt_ptr.new_attempt(player, abilities, attack_id, expiry);
            self.new_combat(attempt_id, 0, 0);
            attempt_id
        }

        fn attack(ref self: ContractState, attempt: felt252, attack: felt252) {
            let mut attempts_ptr = self.attempts;
            let randomness = uuid();
            let (result, success) = attempts_ptr
                .attack::<
                    LAST_USED_ATTACK_HASH, ROUND_HASH,
                >(self.attack_dispatcher.read(), attempt, attack, randomness);
            if success {
                LastUsedAttackTable::set_entity(
                    poseidon_hash_span([attempt, attack].span()),
                    @AttackLastUsed { attack, attempt, combat: 0, round: 0 },
                );
            }
            if result.phase == ArcadePhase::PlayerWon {}
        }

        fn respawn(ref self: ContractState, attempt: felt252) {
            let mut attempts_ptr = self.attempts;
            let mut attempt_ptr = attempts_ptr.entry(attempt);
            let caller = attempt_ptr.assert_caller_is_owner();
            let (stage, respawns) = (attempt_ptr.stage.read(), attempt_ptr.respawns.read());
            let combat_n = stage + respawns;
            let combat = attempt_ptr.combats.entry(combat_n);
            let combat_phase = combat.phase.read();
            assert(attempt_ptr.phase.read() == ArcadePhase::Active, errors::ATTEMPT_DOES_NOT_EXIST);
            match combat_phase {
                ArcadePhase::None => { panic_with_const_felt252::<errors::NOT_ACTIVE>(); },
                ArcadePhase::PlayerWon => {
                    panic_with_const_felt252::<errors::RESPAWN_WHEN_WON>();
                },
                ArcadePhase::Active => { combat.phase.write(ArcadePhase::PlayerLost); },
                ArcadePhase::PlayerLost => {},
            }
            assert(attempt_ptr.respawns.read() < self.max_respawns.read(), 'Max Respawns Reached');
            self.new_combat(attempt, combat_n + 1, stage);
        }

        fn forfeit(ref self: ContractState, attempt: felt252) {
            let mut attempt_ptr = self.attempts.entry(attempt);
            let caller = attempt_ptr.assert_caller_is_owner();
            assert(attempt_ptr.phase.read() == ArcadePhase::Active, errors::NOT_ACTIVE);
            attempt_ptr.phase.write(ArcadePhase::PlayerLost);
        }
    }


    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn new_combat(ref self: ContractState, attempt: felt252, combat_n: u32, stage: u32) {
            assert(stage < self.stages_len.read(), 'Stage does not exist');
            let mut attempt_ptr = self.attempts.entry(attempt);
            let mut combat = attempt_ptr.combats.entry(combat_n);
            let opponent = self.opponents.entry(stage).read();
            let player_abilities = attempt_ptr.abilities.read();
            combat
                .new_combat(
                    player_abilities.into(), opponent.abilities.into(), opponent.attacks.span(),
                );

            RoundTable::set_entity(
                poseidon_hash_span([attempt, combat_n.into(), 0.into()].span()),
                @ArcadeRound {
                    attempt,
                    combat: combat_n,
                    round: 0,
                    player_states: [player_abilities.into(), opponent.abilities.into()],
                    switch_order: false,
                    outcomes: [].span(),
                    phase: ArcadePhase::Active,
                },
            );
        }
    }
}
