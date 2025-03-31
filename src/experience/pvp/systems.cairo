use starknet::ContractAddress;
use dojo::world::WorldStorage;
use crate::erc721::ERC721Token;
use crate::season::SeasonStorage;
use super::PvpExperienceStorage;
use super::super::ExperienceTrait;

#[generate_trait]
impl PVPSeasonImpl of PVPSeason {
    fn calculate_win_points(
        self: @WorldStorage,
        season: felt252,
        winner: ContractAddress,
        winner_token: ERC721Token,
        loser_token: ERC721Token,
        wins: u64,
    ) -> u128 {
        0
    }

    fn claim_win_experience(
        ref self: WorldStorage,
        winner: ContractAddress,
        winner_token: ERC721Token,
        loser_token: ERC721Token,
    ) {
        let season = self.get_current_season(winner_token.collection_address);
        let wins = self.get_pvp_experience_wins(season, winner, winner_token, loser_token) + 1;
        self.set_pvp_experience_wins(season, winner, winner_token, loser_token, wins);
        let points = self.calculate_win_points(season, winner, winner_token, loser_token, wins);
        self
            .increase_experience(
                winner_token.collection_address, winner_token.token_id, winner, points,
            );
    }
}
