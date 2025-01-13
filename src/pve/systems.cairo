use starknet::{ContractAddress, get_contract_address};
use dojo::world::WorldStorage;
use blob_arena::{
    pve::{PVEGame, PVEToken, PVEBlobertInfo, PVEStorage, PVEPhase}, game::{GameStorage, GameTrait},
    combatants::{CombatantStorage, CombatantTrait}, attacks::AttackStorage, world::uuid,
    hash::make_hash_state
};

#[generate_trait]
impl PVEImpl of PVETrait {
    fn new_pve_game(
        ref self: WorldStorage,
        player: ContractAddress,
        player_collection_address: ContractAddress,
        player_token_id: u256,
        player_attacks: Array<(felt252, felt252)>,
        opponent_token: felt252
    ) {
        let game_id = uuid();
        let combatant_id = uuid();
        let opponent_id = uuid();
        self.set_combatant_token(combatant_id, player_collection_address, player_token_id);
        self.set_pve_game(game_id, player, combatant_id, opponent_token, opponent_id);
        self.new_pve_state(game_id);
        self
            .setup_combatant_state_and_attacks(
                combatant_id, player_collection_address, player_token_id, player_attacks
            );
        self.setup_pve_opponent_combatant(opponent_id, opponent_token);
    }
    fn setup_pve_opponent_combatant(
        ref self: WorldStorage, opponent_id: felt252, opponent_token: felt252
    ) {
        let token = self.get_pve_token(opponent_token);
        self.create_combatant_state(opponent_id, token.stats);
        self.set_combatant_attacks_available(opponent_id, token.attacks);
    }
    fn run_pve_round(ref self: WorldStorage, game: PVEGame, randomness: felt252) {
        let state = self.get_pve_state(game.id);
        assert(state.phase == PVEPhase::Active, 'Not active');
        let hash = make_hash_state(randomness);
        let (progress, results) = self
            .run_round(game.id, state.round, [game.player_id, game.opponent_id].span(), hash);
        match progress {
            PVEPhase::Active => {
                self.set_pve_state_round(game.id, state.round + 1);
                
        }
    }
}
