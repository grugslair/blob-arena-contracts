use dojo::event::EventStorage;
use starknet::{get_block_timestamp, get_caller_address, ContractAddress};
use dojo::{world::WorldStorage, model::{ModelStorage, Model}};
use blob_arena::{
    erc721::ERC721Token,
    pvp::components::{
        PvpInfo, Initiator, LastTimestamp, Player, WinVia, CombatEnd, GameInfoTrait, PvpsCompleted,
    },
    combat::{CombatState, Phase, CombatTrait, CombatStorage}, commitments::Commitment,
    combatants::{CombatantStorage, CombatantInfo},
};

fn sort_players(
    player_1: ContractAddress, player_2: ContractAddress,
) -> (ContractAddress, ContractAddress) {
    match player_1 < player_2 {
        true => (player_1, player_2),
        false => (player_2, player_1),
    }
}


#[generate_trait]
impl GameStorageImpl of GameStorage {
    fn get_initiator(self: @WorldStorage, combat_id: felt252) -> ContractAddress {
        self.read_member(Model::<Initiator>::ptr_from_keys(combat_id), selector!("initiator"))
    }

    fn set_initiator(ref self: WorldStorage, combat_id: felt252, initiator: ContractAddress) {
        self.write_model(@Initiator { combat_id, initiator });
    }

    fn get_last_timestamp(self: @WorldStorage, combat_id: felt252) -> u64 {
        self.read_member(Model::<LastTimestamp>::ptr_from_keys(combat_id), selector!("timestamp"))
    }

    fn set_last_timestamp(ref self: WorldStorage, combat_id: felt252, timestamp: u64) {
        self.write_model(@LastTimestamp { combat_id, timestamp });
    }

    fn set_last_timestamp_now(ref self: WorldStorage, combat_id: felt252) {
        self.set_last_timestamp(combat_id, get_block_timestamp());
    }

    fn get_pvp_info(self: @WorldStorage, combat_id: felt252) -> PvpInfo {
        self.read_model(combat_id)
    }

    fn get_pvp_combatants(self: @WorldStorage, combat_id: felt252) -> (felt252, felt252) {
        self.read_member(Model::<PvpInfo>::ptr_from_keys(combat_id), selector!("combatant_ids"))
    }


    fn set_pvp_combatants(
        ref self: WorldStorage, combat_id: felt252, combatant_a: felt252, combatant_b: felt252,
    ) {
        self
            .write_member(
                Model::<PvpInfo>::ptr_from_keys(combat_id),
                selector!("combatant_ids"),
                (combatant_a, combatant_b),
            );
    }

    fn set_pvp_info(
        ref self: WorldStorage,
        combat_id: felt252,
        time_limit: u64,
        combatant_a: felt252,
        combatant_b: felt252,
    ) {
        self
            .write_model(
                @PvpInfo {
                    combat_id: combat_id, time_limit, combatant_ids: (combatant_a, combatant_b),
                },
            );
    }

    fn get_winning_player(self: @WorldStorage, combat_id: felt252) -> ContractAddress {
        self.get_player(self.get_combat_winner(combat_id))
    }

    fn get_combatants_state(
        self: @WorldStorage, combat_id: felt252, combatant_a_id: felt252, combatant_b_id: felt252,
    ) -> (bool, bool) {
        match self.get_combat_phase(combat_id) {
            Phase::Commit => (
                self.check_commitment_set(combatant_a_id),
                self.check_commitment_set(combatant_b_id),
            ),
            Phase::Reveal => (
                self.check_commitment_unset(combatant_a_id),
                self.check_commitment_unset(combatant_b_id),
            ),
            _ => panic!("Not in play phase"),
        }
    }

    fn get_end_player(self: @WorldStorage, combatant: CombatantInfo) -> Player {
        let token = self.get_combatant_token(combatant.id);
        Player {
            combatant_id: combatant.id,
            player: combatant.player,
            token: ERC721Token {
                collection_address: token.collection_address, token_id: token.token_id,
            },
        }
    }

    // fn get_owners_game(
    //     self: @WorldStorage, combat_id: felt252, caller: ContractAddress,
    // ) -> PvpInfo {
    //     let combat = self.get_pvp_info(combat_id);
    //     assert(combat.owner == caller, 'Not the owner');
    //     combat
    // }

    fn emit_combat_end(
        ref self: WorldStorage,
        combat_id: felt252,
        winner: CombatantInfo,
        loser: CombatantInfo,
        via: WinVia,
    ) {
        self
            .emit_event(
                @CombatEnd {
                    combat_id,
                    winner: self.get_end_player(winner),
                    loser: self.get_end_player(loser),
                    via,
                },
            );
    }

    fn get_opponent(self: @WorldStorage, game: PvpInfo, combatant_id: felt252) -> CombatantInfo {
        self.get_combatant_info(game.get_opponent_id(combatant_id))
    }

    fn get_pvps_completed(
        self: @WorldStorage, player_1: ContractAddress, player_2: ContractAddress,
    ) -> u64 {
        self
            .read_member(
                Model::<PvpsCompleted>::ptr_from_keys(sort_players(player_1, player_2)),
                selector!("completed"),
            )
    }

    fn get_pvps_completed_value(
        self: @WorldStorage, players: (ContractAddress, ContractAddress),
    ) -> u64 {
        self.read_member(Model::<PvpsCompleted>::ptr_from_keys(players), selector!("completed"))
    }

    fn set_pvps_completed(
        ref self: WorldStorage, players: (ContractAddress, ContractAddress), completed: u64,
    ) {
        self.write_model(@PvpsCompleted { players, completed });
    }
}
