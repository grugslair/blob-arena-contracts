use starknet::ContractAddress;
use dojo::{world::WorldStorage, model::{ModelStorage, Model}};

#[dojo::model]
#[derive(Drop, Serde)]
struct CurrentSeason {
    #[key]
    collection: ContractAddress,
    season: felt252,
}

#[dojo::event]
#[derive(Drop, Serde)]
struct SeasonName {
    #[key]
    season: felt252,
    name: ByteArray,
}


#[generate_trait]
impl SeasonStorageImpl of SeasonStorage {
    fn get_current_season(self: @WorldStorage, collection: ContractAddress) -> felt252 {
        self.read_member(Model::<CurrentSeason>::ptr_from_keys(collection), selector!("season"))
    }

    fn set_current_season(ref self: WorldStorage, collection: ContractAddress, season: felt252) {
        self.write_model(@CurrentSeason { collection, season });
    }

    fn set_current_season_name(ref self: WorldStorage, season: felt252, name: ByteArray) {
        self.emit_model(@SeasonName { season, name });
    }
}

