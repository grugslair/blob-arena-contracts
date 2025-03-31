use starknet::ContractAddress;
use dojo::world::WorldStorage;
use crate::experience::ExperienceStorage;
use super::SeasonStorage;

#[derive(Drop, Serde)]
struct SeasonCollectionSetup {
    collection: ContractAddress,
    experience_cap: u128,
}


#[generate_trait]
impl SeasonImpl of SeasonTrait {
    fn setup_new_season(
        ref self: WorldStorage,
        season: felt252,
        name: ByteArray,
        collections: Array<SeasonCollectionSetup>,
    ) {
        let mut xp_storage = self.experience_storage();
        self.set_current_season_name(season, name);
        for collection in collections {
            self.set_current_season(collection.collection, season);
            xp_storage.set_experience_cap(collection.collection, collection.experience_cap);
        };
    }
}
