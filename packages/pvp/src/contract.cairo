use ba_combat::{Action, Player};
use starknet::{ClassHash, ContractAddress};

#[starknet::interface]
pub trait IPvp<TContractState> {
    /// ## send_invite
    /// Creates a new lobby invite for a PvP match
    /// * `time_limit` - Time limit for player inactivity in seconds
    /// * `receiver` - Address of the invited receiver
    /// * `collection_address` - NFT collection address for the blobert
    /// * `token_id` - Token ID to use
    /// * `attacks` - Array of attack moves as (felt252, felt252) tuples
    /// * Returns: A felt252 representing the lobby ID
    ///
    fn send_invite(
        ref self: TContractState,
        time_limit: u64,
        receiver: ContractAddress,
        loadout_address: ContractAddress,
        collection_address: ContractAddress,
        token_id: u256,
        attack_slots: Array<Array<felt252>>,
        orb: felt252,
    ) -> felt252;

    /// ## rescind_invite
    /// Cancels an existing lobby invite
    /// * `challenge_id` - ID of the lobby to cancel
    fn rescind_invite(ref self: TContractState, id: felt252);

    /// ## respond_invite
    /// Accepts a lobby invite with specified blob and attacks
    /// * `challenge_id` - ID of the lobby to respond to
    /// * `token_id` - Token ID of the responding player's blob
    /// * `attacks` - Array of attack moves as (felt252, felt252) tuple
    fn respond_invite(
        ref self: TContractState,
        id: felt252,
        collection_address: ContractAddress,
        token_id: u256,
        attack_slots: Array<Array<felt252>>,
        orb: felt252,
    );
    /// ## reject_invite
    /// Rejects an incoming lobby invite
    /// * `challenge_id` - ID of the lobby to reject#
    ///
    fn reject_invite(ref self: TContractState, id: felt252);
    /// ## rescind_response
    /// Withdraws a previous response to an invite
    /// * `challenge_id` - ID of the lobby to withdraw from
    ///
    fn rescind_response(ref self: TContractState, id: felt252);
    /// ## accept_response
    /// Finalizes the lobby and starts the match
    /// * `challenge_id` - ID of the lobby to finalize
    ///
    fn accept_response(ref self: TContractState, id: felt252);
    /// ## reject_response
    /// Rejects a player's response to an invite
    /// * `challenge_id` - ID of the lobby response to reject
    ///
    fn reject_response(ref self: TContractState, id: felt252);

    /// ## commit
    /// Commits to an action for the current round (Only 1 player commits per round)
    /// * `id` - ID of the PvP combat
    /// * `player` - Player committing the action
    /// * `hash` - Hash of the action and salt [salt, action...]
    fn commit(ref self: TContractState, id: felt252, player: Player, hash: felt252);
    /// ## reveal
    /// Reveals the committed action for the current round
    ///     Player that did not commit reveals first, then the committing player
    /// * `id` - ID of the PvP combat
    /// * `player` - Player revealing the action
    /// * `action` - The action being revealed
    /// * `salt` - The salt used in the original hash
    fn reveal(ref self: TContractState, id: felt252, player: Player, action: Action, salt: felt252);
    /// ## forfeit
    ///  Forfeits the current PvP combat, conceding victory to the opponent
    /// * `id` - ID of the PvP combat
    /// * `player` - Player forfeiting the combat
    fn forfeit(ref self: TContractState, id: felt252, player: Player);
    /// ## kick_player
    /// Kicks a player for inactivity after timeout, conceding victory to the opponent
    fn kick_player(ref self: TContractState, id: felt252);
}

#[starknet::interface]
pub trait IPvpAdmin<TContractState> {
    fn set_combat_class_hash(ref self: TContractState, class_hash: ClassHash);
}


#[starknet::contract]
mod pvp {
    use ba_combat::combat::{AttackCheck, CombatProgress, RoundZeroResult, set_attacks_available};
    use ba_combat::systems::{get_attack_dispatcher, set_attack_dispatcher_address};
    use ba_combat::{Action, CombatantState, RoundResult, library_run_round};
    use ba_loadout::get_loadout;
    use ba_orbs::OrbTrait;
    use ba_utils::{RandomnessTrait, uuid};
    use beacon_library::{ToriiTable, register_table, register_table_with_schema};
    use core::num::traits::Zero;
    use core::{panic_with_const_felt252, panic_with_felt252};
    use sai_core_utils::{poseidon_hash_serde, poseidon_hash_two};
    use sai_ownable::{OwnableTrait, ownable_component};
    use sai_token::erc721::erc721_owner_of;
    use starknet::storage::{
        Map, Mutable, PendingStoragePath, StoragePath, StoragePathEntry, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ClassHash, ContractAddress, get_block_timestamp, get_caller_address};
    use crate::components::{
        AddressOrPtr, AddressOrPtrTrait, CombatPhase, LobbyNode, LobbyPhase, MaybePlayers, PvpNode,
        PvpNodePath, PvpNodeTrait,
    };
    use crate::tables::{
        LobbyCombatInitSchema, LobbyCombatRespondSchema, LobbyCombatStartSchema,
        PvpAttackLastUsedTable, PvpCombatTable, WinVia,
    };
    use crate::utils::pad_to_fixed;
    use super::{IPvp, IPvpAdmin, Player};

    component!(path: ownable_component, storage: ownable, event: OwnableEvents);

    const COMBAT_HASH: felt252 = bytearrays_hash!("pvp", "Combat");
    const ROUND_HASH: felt252 = bytearrays_hash!("pvp", "Round");
    const LAST_USED_ATTACK_HASH: felt252 = bytearrays_hash!("pvp", "AttackLastUsed");

    impl CombatTable = ToriiTable<COMBAT_HASH>;
    impl RoundTable = ToriiTable<ROUND_HASH>;
    impl LastUsedAttackTable = ToriiTable<LAST_USED_ATTACK_HASH>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: ownable_component::Storage,
        lobbies: Map<felt252, LobbyNode>,
        combats: Map<felt252, PvpNode>,
        combat_class_hash: ClassHash,
        orb_address: ContractAddress,
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
        round_result_class_hash: ClassHash,
        attack_address: ContractAddress,
    ) {
        self.grant_owner(owner);
        register_table_with_schema::<PvpCombatTable>("pvp", "Combat");
        register_table_with_schema::<PvpAttackLastUsedTable>("pvp", "AttackLastUsed");
        register_table("pvp", "Round", round_result_class_hash);
        set_attack_dispatcher_address(attack_address);
    }

    #[abi(embed_v0)]
    impl IPvpAdminImpl of IPvpAdmin<ContractState> {
        fn set_combat_class_hash(ref self: ContractState, class_hash: ClassHash) {
            self.assert_caller_is_owner();
            self.combat_class_hash.write(class_hash);
        }
    }

    #[abi(embed_v0)]
    impl IPvpImpl of IPvp<ContractState> {
        fn send_invite(
            ref self: ContractState,
            time_limit: u64,
            receiver: ContractAddress,
            loadout_address: ContractAddress,
            collection_address: ContractAddress,
            token_id: u256,
            attack_slots: Array<Array<felt252>>,
            orb: felt252,
        ) -> felt252 {
            let id = uuid();
            let player = get_caller_address();
            assert(attack_slots.len() <= 4, 'Too many attacks');
            assert(erc721_owner_of(collection_address, token_id) == player, 'Not Token Owner');

            let mut combat = self.combats.entry(id);
            let mut lobby = self.lobbies.entry(id);

            let (attributes, attack_ids) = get_loadout(
                loadout_address, collection_address, token_id, attack_slots,
            );

            combat.player_1.write(player);
            combat.player_2.write(receiver);
            combat.orb_1.write(orb);
            combat.time_limit.write(time_limit);
            lobby.set_lobby_phase(id, LobbyPhase::Invited);
            lobby.loadout_address.write(loadout_address);
            lobby.attributes_1.write(attributes);

            CombatTable::set_schema(
                id,
                @LobbyCombatInitSchema {
                    lobby: LobbyPhase::Invited,
                    player_1: player,
                    player_2: receiver,
                    p1_loadout: loadout_address,
                    p2_loadout: loadout_address,
                    p1_token: (collection_address, token_id),
                    p1_attacks: attack_ids.span(),
                    p1_orb: orb,
                    time_limit,
                },
            );
            set_attacks_available(id, Player::Player1, attack_ids.span());
            id
        }

        fn rescind_invite(ref self: ContractState, id: felt252) {
            let caller = get_caller_address();
            let mut lobby = self.lobbies.entry(id);
            let combat = self.combats.entry(id);
            assert(lobby.phase.read() == LobbyPhase::Invited, 'Lobby not active');
            assert(combat.player_1.read() == caller, 'Not Callers Lobby');
            lobby.set_lobby_phase(id, LobbyPhase::InActive);
        }

        fn respond_invite(
            ref self: ContractState,
            id: felt252,
            collection_address: ContractAddress,
            token_id: u256,
            attack_slots: Array<Array<felt252>>,
            orb: felt252,
        ) {
            let caller = get_caller_address();
            let mut lobby = self.lobbies.entry(id);
            let combat = self.combats.entry(id);
            combat.orb_2.write(orb);
            assert(combat.player_2.read() == caller, 'Not Callers Lobby');
            assert(lobby.phase.read() == LobbyPhase::Invited, 'Lobby not active');
            assert(attack_slots.len() <= 4, 'Too many attacks');
            assert(erc721_owner_of(collection_address, token_id) == caller, 'Not Token Owner');

            let (attributes, attack_ids) = get_loadout(
                lobby.loadout_address.read(), collection_address, token_id, attack_slots,
            );

            let attack_ids = pad_to_fixed(attack_ids);
            lobby.combatant_2.write((attributes, attack_ids));
            lobby.phase.write(LobbyPhase::Responded);
            CombatTable::set_schema(
                id,
                @LobbyCombatRespondSchema {
                    lobby: LobbyPhase::Responded,
                    p2_token: (collection_address, token_id),
                    p2_attacks: attack_ids.span(),
                    p2_orb: orb,
                },
            );
        }

        fn reject_invite(ref self: ContractState, id: felt252) {
            let caller = get_caller_address();
            let mut lobby = self.lobbies.entry(id);
            let combat = self.combats.entry(id);
            match lobby.phase.read() {
                LobbyPhase::InActive => panic_with_const_felt252::<'Lobby not active'>(),
                LobbyPhase::Accepted => panic_with_const_felt252::<'Lobby already accepted'>(),
                _ => {},
            }

            assert(combat.player_2.read() == caller, 'Not Callers Lobby');
            lobby.set_lobby_phase(id, LobbyPhase::InActive);
        }

        fn rescind_response(ref self: ContractState, id: felt252) {
            let caller = get_caller_address();
            let mut lobby = self.lobbies.entry(id);
            let combat = self.combats.entry(id);
            assert(lobby.phase.read() == LobbyPhase::Responded, 'Lobby not responded');
            assert(combat.player_2.read() == caller, 'Not Callers Lobby');
            lobby.set_lobby_phase(id, LobbyPhase::Invited);
        }

        fn reject_response(ref self: ContractState, id: felt252) {
            let caller = get_caller_address();
            let mut lobby = self.lobbies.entry(id);
            let combat = self.combats.entry(id);
            assert(lobby.phase.read() == LobbyPhase::Responded, 'Lobby not responded');
            assert(combat.player_1.read() == caller, 'Not Callers Lobby');
            lobby.set_lobby_phase(id, LobbyPhase::Invited);
        }

        fn accept_response(ref self: ContractState, id: felt252) {
            let caller = get_caller_address();
            let mut lobby = self.lobbies.entry(id);
            let mut combat = self.combats.entry(id);
            assert(lobby.phase.read() == LobbyPhase::Responded, 'Lobby not responded');
            assert(combat.player_1.read() == caller, 'Not Callers Lobby');

            let attributes_1 = lobby.attributes_1.read();
            let (attributes_2, attack_ids_2) = lobby.combatant_2.read();
            let states: [CombatantState; 2] = [attributes_1.into(), attributes_2.into()];
            combat.player_states.write(states);
            set_attacks_available(id, Player::Player2, attack_ids_2.span());
            RoundTable::set_schema(
                id, @RoundZeroResult { combat: id, states, progress: CombatProgress::Active },
            );
            combat.set_next_round(id, 0);
            lobby.phase.write(LobbyPhase::Accepted);
        }
        fn commit(ref self: ContractState, id: felt252, player: Player, hash: felt252) {
            let mut combat = self.combats.entry(id);
            let phase = combat.phase.read();
            combat.assert_caller_is_player(player);
            assert(phase == CombatPhase::Commit, 'Combat not in commit phase');
            match player {
                Player::Player1 => combat
                    .set_combat_phase_and_time(id, CombatPhase::Player1Committed),
                Player::Player2 => combat
                    .set_combat_phase_and_time(id, CombatPhase::Player2Committed),
            }
            combat.commit.write(hash);
        }
        fn reveal(
            ref self: ContractState, id: felt252, player: Player, action: Action, salt: felt252,
        ) {
            let mut combat = self.combats.entry(id);
            let mut maybe_players = combat.assert_caller_is_player_return_maybe(player);
            let phase = combat.phase.read();
            let (run, next_phase) = match (phase, player) {
                (CombatPhase::Player1Committed, Player::Player1) |
                (CombatPhase::Player2Committed, Player::Player2) |
                (CombatPhase::Player1Revealed, Player::Player1) |
                (
                    CombatPhase::Player2Revealed, Player::Player2,
                ) => panic_with_felt252('Waiting on other player'),
                (CombatPhase::Player1Committed, _) => (false, CombatPhase::Player1Revealed),
                (CombatPhase::Player2Committed, _) => (false, CombatPhase::Player2Revealed),
                (CombatPhase::Player1Revealed, _) => (true, CombatPhase::WinnerPlayer2),
                (CombatPhase::Player2Revealed, _) => (true, CombatPhase::WinnerPlayer1),
                _ => panic_with_felt252('Not in reveal phase'),
            };
            if !run {
                combat.reveal.write((action, salt));
                combat.set_combat_phase_and_time(id, next_phase);
            } else if combat.commit.read() == poseidon_hash_serde(@(salt, action)) {
                let result = self.run_round(combat, id, next_phase, action, salt, maybe_players);
                match result.progress {
                    CombatProgress::Active => combat.set_next_round(id, result.round),
                    CombatProgress::Ended(Player::Player1) => combat
                        .set_win_phase(id, CombatPhase::WinnerPlayer1, WinVia::Combat),
                    CombatProgress::Ended(Player::Player2) => combat
                        .set_win_phase(id, CombatPhase::WinnerPlayer2, WinVia::Combat),
                    CombatProgress::None => panic_with_felt252('Invalid combat progress'),
                }
                combat.player_states.write(result.states);
                RoundTable::set_entity(id + result.round.into(), @result);
            } else {
                combat.set_win_phase(id, next_phase, WinVia::IncorrectReveal);
            }
        }

        fn forfeit(ref self: ContractState, id: felt252, player: Player) {
            let mut combat = self.combats.entry(id);
            combat.assert_caller_is_player(player);
            match combat.phase.read() {
                CombatPhase::None | CombatPhase::Created | CombatPhase::WinnerPlayer1 |
                CombatPhase::WinnerPlayer2 => panic_with_felt252('Combat not in forfeit phase'),
                _ => {},
            }
            combat
                .set_win_phase(
                    id,
                    match player {
                        Player::Player1 => CombatPhase::WinnerPlayer2,
                        Player::Player2 => CombatPhase::WinnerPlayer1,
                    },
                    WinVia::Forfeit,
                );
        }

        fn kick_player(ref self: ContractState, id: felt252) {
            let mut combat = self.combats.entry(id);

            let (player, next_phase) = match combat.phase.read() {
                CombatPhase::Player1Committed |
                CombatPhase::Player1Revealed => (Player::Player1, CombatPhase::WinnerPlayer2),
                CombatPhase::Player2Committed |
                CombatPhase::Player2Revealed => (Player::Player2, CombatPhase::WinnerPlayer1),
                _ => panic_with_felt252('Combat not in combat phase'),
            };
            let timeout = combat.time_limit.read();
            assert(timeout.is_non_zero(), 'No timeout set');
            assert(
                get_block_timestamp() > (combat.timestamp.read() + timeout), 'Combat not timed out',
            );
            combat.assert_caller_is_player(player);
            combat.set_win_phase(id, next_phase, WinVia::TimedOut);
        }
    }

    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn run_round<T, +Drop<T>, +AddressOrPtrTrait<T>>(
            ref self: ContractState,
            node: PvpNodePath,
            combat_id: felt252,
            phase: CombatPhase,
            action: Action,
            salt: felt252,
            players: MaybePlayers<T>,
        ) -> RoundResult {
            let [(action_1, salt_1), (action_2, salt_2)] = match phase {
                CombatPhase::Player1Revealed => [(action, salt), node.reveal.read()],
                CombatPhase::Player2Revealed => [node.reveal.read(), (action, salt)],
                _ => panic_with_felt252('Invalid combat phase'),
            };
            let [state_1, state_2] = node.player_states.read();
            let randomness = RandomnessTrait::new(poseidon_hash_two(salt_1, salt_2));
            let mut orb_address = AddressOrPtr::Ptr(self.orb_address);
            let (attack_1, check_1) = self
                .get_attack_and_check(ref orb_address, action_1, players.player1, node.orb_1);
            let (attack_2, check_2) = self
                .get_attack_and_check(ref orb_address, action_2, players.player2, node.orb_2);

            let (result, _) = library_run_round(
                self.combat_class_hash.read(),
                combat_id,
                node.round.read(),
                state_1,
                state_2,
                attack_1,
                attack_2,
                check_1,
                check_2,
                get_attack_dispatcher(),
                randomness,
            );
            result
        }

        fn set_lobby_phase(self: StoragePath<Mutable<LobbyNode>>, id: felt252, phase: LobbyPhase) {
            CombatTable::set_member(selector!("lobby"), id, @phase);
            self.phase.write(phase);
        }

        fn set_next_round(self: StoragePath<Mutable<PvpNode>>, id: felt252, mut round: u32) {
            round += 1;
            self.phase.write(CombatPhase::Commit);
            self.round.write(round);
            CombatTable::set_schema(
                id, @LobbyCombatStartSchema { round, phase: CombatPhase::Commit },
            );
        }

        fn set_combat_phase_and_time(
            self: StoragePath<Mutable<PvpNode>>, id: felt252, phase: CombatPhase,
        ) {
            let time_stamp = get_block_timestamp();
            if self.time_limit.read().is_non_zero() {
                self.timestamp.write(time_stamp);
                CombatTable::set_member(selector!("timestamp"), id, @time_stamp);
            }
            CombatTable::set_member(selector!("phase"), id, @phase);
        }

        fn set_win_phase(
            self: StoragePath<Mutable<PvpNode>>, id: felt252, phase: CombatPhase, via: WinVia,
        ) {
            CombatTable::set_member(selector!("phase"), id, @phase);
            CombatTable::set_member(selector!("win_via"), id, @via);

            self.phase.write(phase);
        }


        fn get_attack_and_check<
            T, S, +Drop<T>, +Drop<S>, +AddressOrPtrTrait<T>, +AddressOrPtrTrait<S>,
        >(
            ref self: ContractState,
            ref orb_address: AddressOrPtr<T>,
            action: Action,
            player_address: AddressOrPtr<S>,
            orb_ptr: PendingStoragePath<Mutable<felt252>>,
        ) -> (felt252, AttackCheck) {
            match action {
                Action::Attack(attack_id) => (attack_id, AttackCheck::All),
                Action::Orb(orb_id) => {
                    let attack_id = if orb_id == orb_ptr.read() {
                        match orb_address
                            .read()
                            .try_use_owners_charge_cost(player_address.final_read(), orb_id) {
                            Some(attack_id) => {
                                orb_ptr.write(0);
                                attack_id
                            },
                            None => 0,
                        }
                    } else {
                        0
                    };
                    (attack_id, AttackCheck::None)
                },
                Action::None => (0, AttackCheck::None),
            }
        }
    }
}
