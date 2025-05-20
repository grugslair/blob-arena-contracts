use starknet::ContractAddress;
use dojo::event::EventStorage;
use dojo::model::{ModelStorage, Model};
use dojo::world::WorldStorage;
use crate::world::{WorldTrait, NsModelStorage};
use crate::stats::UStats;
use super::super::items::{BlobertItemStorage};
use super::super::{BlobertItemKey, TokenAttributes};
use super::super::world_blobert::WorldBlobertStorage;
const AMMA_BLOBERT_NAMESPACE_HASH: felt252 = bytearray_hash!("amma_blobert");

/// Tracks if a player has minted their first token in the Amma Blobert collection.
///
/// # Fields
/// * `player` - The contract address of the player.
/// * `minted` - A boolean indicating whether the player has minted their first token (true) or not
/// (false).
#[dojo::model]
#[derive(Drop, Serde)]
struct FirstTokenMinted {
    #[key]
    player: ContractAddress,
    minted: bool,
}

/// Tracks if a specific arcade attempt has resulted in a token mint.
///
/// # Fields
/// * `attempt_id` - The unique identifier of the arcade challenge attempt.
/// * `minted` - A boolean indicating whether this attempt has resulted in a token mint (true) or
/// not (false).
#[dojo::model]
#[derive(Drop, Serde)]
struct ArcadeAttemptMinted {
    #[key]
    attempt_id: felt252,
    minted: bool,
}

/// Represents a fighter character within the Amma Blobert collection.
///
/// # Fields
/// * `id` - The unique identifier for the Amma Fighter.
/// * `stats` - The base statistics of the fighter.
/// * `generated_stats` - The dynamically generated statistics for an instance of this fighter
/// (e.g., in an arcade).
/// * `attacks` - The number of attacks or attack slots available to this fighter.
#[dojo::model]
#[derive(Drop, Serde)]
struct AmmaFighter {
    #[key]
    id: u32,
    stats: UStats,
    generated_stats: UStats,
    attacks: u32,
}

/// Event emitted when the name of an Amma Fighter is set or updated.
///
/// # Fields
/// * `fighter` - The unique identifier of the Amma Fighter whose name is being set.
/// * `name` - The new name assigned to the fighter.
#[dojo::event]
#[derive(Serde, Drop)]
struct AmmaFighterName {
    #[key]
    fighter: u32,
    name: ByteArray,
}

#[generate_trait]
impl AmmaBlobertStorageImpl of AmmaBlobertStorage {
    fn get_first_token_minted(self: @WorldStorage, player: ContractAddress) -> bool {
        self.read_member(Model::<FirstTokenMinted>::ptr_from_keys(player), selector!("minted"))
    }

    fn set_first_token_minted(ref self: WorldStorage, player: ContractAddress) {
        self.write_model(@FirstTokenMinted { player, minted: true })
    }

    fn assert_first_token_not_minted(ref self: WorldStorage, player: ContractAddress) {
        assert(!self.get_first_token_minted(player), 'First token already minted');
    }

    fn get_attempt_minted(self: @WorldStorage, attempt_id: felt252) -> bool {
        self
            .read_member(
                Model::<ArcadeAttemptMinted>::ptr_from_keys(attempt_id), selector!("minted"),
            )
    }
    fn set_arcade_attempt_minted(ref self: WorldStorage, attempt_id: felt252) {
        self.write_model(@ArcadeAttemptMinted { attempt_id, minted: true })
    }
    fn assert_arcade_attempt_not_minted(ref self: WorldStorage, attempt_id: felt252) {
        assert(!self.get_attempt_minted(attempt_id), 'Attempt already minted');
    }
    fn assert_and_set_first_token_minted(ref self: WorldStorage, player: ContractAddress) {
        self.assert_first_token_not_minted(player);
        self.set_first_token_minted(player);
    }

    fn assert_and_set_arcade_attempt_minted(ref self: WorldStorage, attempt_id: felt252) {
        self.assert_arcade_attempt_not_minted(attempt_id);
        self.set_arcade_attempt_minted(attempt_id);
    }

    fn set_amma_fighter(
        ref self: WorldStorage,
        fighter: u32,
        name: ByteArray,
        stats: UStats,
        generated_stats: UStats,
        attacks: u32,
    ) {
        self.emit_event(@AmmaFighterName { fighter, name });
        self.write_model(@AmmaFighter { id: fighter, stats, generated_stats, attacks })
    }

    fn set_amma_fighter_stats(ref self: WorldStorage, fighter: u32, stats: UStats) {
        self.write_member(Model::<AmmaFighter>::ptr_from_keys(fighter), selector!("stats"), stats)
    }

    fn set_amma_fighter_generated_stats(ref self: WorldStorage, fighter: u32, stats: UStats) {
        self
            .write_member(
                Model::<AmmaFighter>::ptr_from_keys(fighter), selector!("generated_stats"), stats,
            )
    }
    fn set_amma_fighter_attacks(ref self: WorldStorage, fighter: u32, attacks: u32) {
        self
            .write_member(
                Model::<AmmaFighter>::ptr_from_keys(fighter), selector!("attacks"), attacks,
            )
    }
    fn set_amma_fighter_name(ref self: WorldStorage, fighter: u32, name: ByteArray) {
        self.emit_event(@AmmaFighterName { fighter, name });
    }

    fn get_amma_fighter_stats(self: @WorldStorage, fighter: felt252) -> UStats {
        self
            .read_ns_member(
                AMMA_BLOBERT_NAMESPACE_HASH,
                Model::<AmmaFighter>::ptr_from_keys(fighter),
                selector!("stats"),
            )
    }

    fn get_amma_fighter_generated_stats(self: @WorldStorage, fighter: felt252) -> UStats {
        self
            .read_ns_member(
                AMMA_BLOBERT_NAMESPACE_HASH,
                Model::<AmmaFighter>::ptr_from_keys(fighter),
                selector!("generated_stats"),
            )
    }
    fn get_amma_fighter_attacks_amount(self: @WorldStorage, fighter: felt252) -> u32 {
        self.read_member(Model::<AmmaFighter>::ptr_from_keys(fighter), selector!("attacks"))
    }
    fn get_amma_fighter_attacks(self: @WorldStorage, fighter: felt252) -> Array<felt252> {
        let storage = self.storage(AMMA_BLOBERT_NAMESPACE_HASH);
        let amount = storage.get_amma_fighter_attacks_amount(fighter);
        let mut attack_slots: Array<(BlobertItemKey, felt252)> = Default::default();
        for i in 0..amount {
            attack_slots.append((BlobertItemKey::Custom(fighter), i.into()));
        };
        storage.get_blobert_attack_slots(attack_slots.span())
    }
    fn get_amma_token_fighter(self: @WorldStorage, token_id: u256) -> u32 {
        match self.get_blobert_token_attributes(token_id) {
            TokenAttributes::Custom(fighter) => { fighter.try_into().unwrap() },
            TokenAttributes::Seed => { panic!("Amma cannot use a seed") },
        }
    }
}
