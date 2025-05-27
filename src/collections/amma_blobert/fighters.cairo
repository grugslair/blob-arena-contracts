use crate::stats::UStats;

#[derive(Drop, Serde, Default, PartialEq)]
enum AmmaFighter {
    #[default]
    None,
}


#[generate_trait]
impl AmmaFighterStatsImpl of AmmaFighterStats {
    fn strength(self: @AmmaFighter) -> u8 {
        match self {
            AmmaFighter::None => panic!("None"),
        }
    }
    fn vitality(self: @AmmaFighter) -> u8 {
        match self {
            AmmaFighter::None => panic!("None"),
        }
    }
    fn dexterity(self: @AmmaFighter) -> u8 {
        match self {
            AmmaFighter::None => panic!("None"),
        }
    }
    fn luck(self: @AmmaFighter) -> u8 {
        match self {
            AmmaFighter::None => panic!("None"),
        }
    }
    fn stats(self: @AmmaFighter) -> UStats {
        UStats {
            strength: self.strength(),
            vitality: self.vitality(),
            dexterity: self.dexterity(),
            luck: self.luck(),
        }
    }
}
