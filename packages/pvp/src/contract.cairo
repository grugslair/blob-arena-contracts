use ba_combat::Player;
use starknet::ContractAddress;

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

    fn commit(ref self: TContractState, id: felt252, player: Player, hash: felt252);
    fn reveal(
        ref self: TContractState, id: felt252, player: Player, attack: felt252, salt: felt252,
    );
    fn forfeit(ref self: TContractState, id: felt252, player: Player);
    fn kick_player(ref self: TContractState, id: felt252);
}


#[starknet::contract]
mod pvp {
    use ba_combat::CombatantState;
    use ba_combat::combat::CombatProgress;
    use ba_loadout::attack::IAttackDispatcher;
    use ba_loadout::get_loadout;
    use ba_utils::uuid;
    use beacon_library::{ToriiTable, register_table_with_schema};
    use core::num::traits::Zero;
    use core::{panic_with_const_felt252, panic_with_felt252};
    use sai_core_utils::poseidon_hash_two;
    use sai_token::erc721::erc721_owner_of;
    use starknet::storage::{
        Map, Mutable, StorageMapWriteAccess, StoragePath, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use crate::components::{CombatPhase, LobbyNode, LobbyPhase, PvpNode, PvpNodeTrait};
    use crate::tables::{
        Lobby, LobbyCombatInitSchema, LobbyCombatRespondSchema, LobbyCombatStartSchema,
        PvpAttackLastUsedTable, PvpCombatTable, PvpFirstRoundSchema, PvpRoundTable,
        PvpRoundTableTrait, WinVia,
    };
    use crate::utils::pad_to_fixed;
    use super::{IPvp, Player};

    const LOBBY_HASH: felt252 = bytearrays_hash!("pvp", "Lobby");
    const COMBAT_HASH: felt252 = bytearrays_hash!("pvp", "Combat");
    const ROUND_HASH: felt252 = bytearrays_hash!("pvp", "Round");
    const LAST_USED_ATTACK_HASH: felt252 = bytearrays_hash!("pvp", "AttackLastUsed");

    impl LobbyTable = ToriiTable<LOBBY_HASH>;
    impl CombatTable = ToriiTable<COMBAT_HASH>;
    impl RoundTable = ToriiTable<ROUND_HASH>;
    impl LastUsedAttackTable = ToriiTable<LAST_USED_ATTACK_HASH>;

    #[storage]
    struct Storage {
        lobbies: Map<felt252, LobbyNode>,
        combats: Map<felt252, PvpNode>,
        attack_dispatcher: IAttackDispatcher,
    }

    #[constructor]
    fn constructor(ref self: ContractState, attack_address: ContractAddress) {
        register_table_with_schema::<Lobby>("pvp", "Lobby");
        register_table_with_schema::<PvpCombatTable>("pvp", "Combat");
        register_table_with_schema::<PvpRoundTable>("pvp", "Round");
        register_table_with_schema::<PvpAttackLastUsedTable>("pvp", "AttackLastUsed");
        self.attack_dispatcher.write(IAttackDispatcher { contract_address: attack_address });
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
        ) -> felt252 {
            let id = uuid();
            let player = get_caller_address();
            assert(attack_slots.len() <= 4, 'Too many attacks');
            assert(erc721_owner_of(collection_address, token_id) == player, 'Not Token Owner');

            let mut combat = self.combats.entry(id);
            let mut lobby = self.lobbies.entry(id);

            let (abilities, attack_ids) = get_loadout(
                loadout_address, collection_address, token_id, attack_slots,
            );

            combat.player_1.write(player);
            combat.player_2.write(receiver);
            combat.time_limit.write(time_limit);
            lobby.set_lobby_phase(id, LobbyPhase::Invited);
            lobby.loadout_address.write(loadout_address);
            lobby.abilities_1.write(abilities);

            CombatTable::set_schema(
                id,
                @LobbyCombatInitSchema {
                    player_1: player,
                    player_2: receiver,
                    p1_loadout: loadout_address,
                    p2_loadout: loadout_address,
                    p1_token: (collection_address, token_id),
                    p1_attacks: attack_ids.span(),
                    time_limit,
                },
            );
            for attack_id in attack_ids {
                combat.p1_attack_available.write(attack_id, true);
            }
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
        ) {
            let caller = get_caller_address();
            let mut lobby = self.lobbies.entry(id);
            let combat = self.combats.entry(id);

            assert(combat.player_2.read() == caller, 'Not Callers Lobby');
            assert(lobby.phase.read() == LobbyPhase::Invited, 'Lobby not active');
            assert(attack_slots.len() <= 4, 'Too many attacks');
            assert(erc721_owner_of(collection_address, token_id) == caller, 'Not Token Owner');

            let (abilities, attack_ids) = get_loadout(
                lobby.loadout_address.read(), collection_address, token_id, attack_slots,
            );

            let attack_ids = pad_to_fixed(attack_ids);
            lobby.combatant_2.write((abilities, attack_ids));
            CombatTable::set_schema(
                id,
                @LobbyCombatRespondSchema {
                    p2_token: (collection_address, token_id), p2_attacks: attack_ids.span(),
                },
            );

            lobby.set_lobby_phase(id, LobbyPhase::Responded);
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

            let abilities_1 = lobby.abilities_1.read();
            let (abilities_2, attack_ids_2) = lobby.combatant_2.read();
            let states: [CombatantState; 2] = [abilities_1.into(), abilities_2.into()];
            combat.player_states.write(states);
            for attack_id in attack_ids_2.span() {
                combat.p2_attack_available.write(*attack_id, true);
            }
            RoundTable::set_schema(
                id, @PvpFirstRoundSchema { combat: id, round: 0, states: states.span() },
            );
            combat.set_next_round(id, 0);
            lobby.set_lobby_phase(id, LobbyPhase::Accepted);
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
            ref self: ContractState, id: felt252, player: Player, attack: felt252, salt: felt252,
        ) {
            let mut combat = self.combats.entry(id);
            combat.assert_caller_is_player(player);
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
                combat.reveal.write([attack, salt]);
                combat.set_combat_phase_and_time(id, next_phase);
            } else if combat.commit.read() == poseidon_hash_two(attack, salt) {
                let result = combat.run_round(self.attack_dispatcher.read(), phase, attack, salt);
                match result.progress {
                    CombatProgress::Active => combat.set_next_round(id, result.round),
                    CombatProgress::Ended(winner) => match winner {
                        Player::Player1 => combat
                            .set_win_phase(id, CombatPhase::WinnerPlayer1, WinVia::Combat),
                        Player::Player2 => combat
                            .set_win_phase(id, CombatPhase::WinnerPlayer2, WinVia::Combat),
                    },
                }
                combat.player_states.write(result.states);
                RoundTable::set_entity(
                    poseidon_hash_two(id, result.round), @result.to_pvp_round(id),
                );
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
            combat.assert_caller_is_player(player);
            combat.set_win_phase(id, next_phase, WinVia::TimedOut);
        }
    }

    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn set_lobby_phase(self: StoragePath<Mutable<LobbyNode>>, id: felt252, phase: LobbyPhase) {
            LobbyTable::set_entity(id, @phase);
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
    }
}
