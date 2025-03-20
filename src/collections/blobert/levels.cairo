use starknet::ContractAddress;
use dojo::{world::WorldStorage, model::{Model, ModelStorage}};
use crate::stats::{UStats, StatsTrait};

const STATS_PER_LEVEL: u16 = 3;

#[dojo::model]
#[derive(Drop, Serde)]
struct BlobertLevelStats {
    #[key]
    token: u256,
    #[key]
    player: ContractAddress,
    strength: u8,
    vitality: u8,
    dexterity: u8,
    luck: u8,
}

fn calculate_max_level_stats(experience: u128) -> u16 {
    0
}

#[generate_trait]
impl BlobertLevelsStorageImpl of BlobertLevelsStorage {
    fn get_blobert_level(
        self: @WorldStorage, level: u16, token: u256, player: ContractAddress,
    ) -> u16 {
        self
            .read_member(
                Model::<BlobertLevel>::ptr_from_keys((level, token, player)), selector!("claimed"),
            )
    }

    fn set_blobert_level(
        ref self: WorldStorage, level: u16, token: u256, player: ContractAddress, level: u16,
    ) {
        self.write_model(@BlobertLevel { level, token, player, level });
    }

    fn get_blobert_level_stats(
        self: @WorldStorage, token: u256, player: ContractAddress,
    ) -> UStats {
        self.read_schema(Model::<BlobertLevelStats>::ptr_from_keys((token, player)))
    }

    fn set_blobert_level_stats(
        ref self: WorldStorage, token: u256, player: ContractAddress, stats: UStats,
    ) {
        let UStats { strength, vitality, dexterity, luck } = stats;
        self.write_model(@BlobertLevelStats { token, player, strength, vitality, dexterity, luck });
    }
}

#[generate_trait]
impl BlobertLevelImpl of BlobertLevelTrait {
    // fn claim_level(ref self: WorldStorage, level: u16, token: u256, player: ContractAddress) {
    //     if level > 0 {
    //         assert(self.get_level_claimed(level - 1, token, player), 'Previous level not
    //         claimed');
    //     }
    //     assert(!self.get_level_claimed(level, token, player), 'Level already claimed');
    //     self.set_level_claimed(level, token, player, true);
    // }

    // fn claim_levels(
    //     ref self: WorldStorage, level: u16, n_levels: u16, token: u256, player: ContractAddress,
    // ) {
    //     if level > 0 {
    //         assert(self.get_level_claimed(level - 1, token, player), 'Previous level not
    //         claimed');
    //     }
    //     let mut keys = ArrayTrait::<(u16, u256, ContractAddress)>::new();
    //     let mut models = ArrayTrait::<@LevelClaimed>::new();
    //     for l in level..(level + n_levels) {
    //         keys.append((l, token, player));
    //         models.append(@LevelClaimed { level: l, token, player, claimed: true });
    //     };
    //     let claimed: Array<bool> = self
    //         .read_member_of_models(
    //             Model::<LevelClaimed>::ptrs_from_keys(keys), selector!("claimed"),
    //         );
    //     for c in claimed {
    //         assert(!c, 'Level already claimed');
    //     };
    //     self.write_models(models).span();
    // }

    // fn increase_stats(ref self: WorldStorage, token: u256, player: ContractAddress, stats:
    // UStats) {
    //     let new_stats = self.get_blobert_level_stats(token, player) + stats;
    //     new_stats.assert_in_range();
    //     self.set_blobert_level_stats(token, player);
    // }

    fn level_up(
        ref self: WorldStorage, token: u256, player: ContractAddress, stats_increase: UStats,
    ) {
        let max_stats = calculate_max_level_stats();
        let new_stats = self.get_blobert_level_stats() + stats_increase;
        assert(new_stats < max_stats, 'Not enough experience');
        assert(new_stats.assert_in_range(), 'Stats out of range');
        self.set_blobert_level_stats(token, player, new_stats);
    }
}
