use starknet::ContractAddress;
use dojo::{world::WorldStorage, model::{ModelStorage, Model}};
use crate::erc721::ERC721Token;

#[dojo::model]
#[derive(Drop, Serde)]
struct PvpSeasonWins {
    #[key]
    season: felt252,
    #[key]
    player: ContractAddress,
    #[key]
    player_token: ERC721Token,
    #[key]
    opponent_token: ERC721Token,
    wins: u64,
}

#[generate_trait]
impl PvpExperienceImpl of PvpExperienceStorage {
    fn get_pvp_experience_wins(
        self: @WorldStorage,
        season: felt252,
        player: ContractAddress,
        player_token: ERC721Token,
        opponent_token: ERC721Token,
    ) -> u64 {
        self
            .read_member(
                Model::<
                    PvpSeasonWins,
                >::ptr_from_keys((season, player, player_token, opponent_token)),
                selector!("wins"),
            )
    }
    fn set_pvp_experience_wins(
        ref self: WorldStorage,
        season: felt252,
        player: ContractAddress,
        player_token: ERC721Token,
        opponent_token: ERC721Token,
        wins: u64,
    ) {
        self.write_model(@PvpSeasonWins { season, player, player_token, opponent_token, wins });
    }
}

