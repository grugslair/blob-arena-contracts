use starknet::ContractAddress;
use super::super::TokenAttributes;
use crate::tags::IdTagNew;
use crate::attacks::AttackInput;
use crate::stats::UStats;


#[starknet::interface]
trait IAmmaBlobert<TContractState> {
    /// Mints a free Blobert token
    /// # Returns
    /// * `Array<u256>` - An array containing the token id(s) of the minted Blobert(s)
    fn mint_free(ref self: TContractState) -> Array<u256>;
    /// Mints a Blobert token using an arcade unlock attempt
    /// # Arguments
    /// * `attempt_id` - The unique identifier for the arcade attempt that was won
    /// # Returns
    /// * `u256` - The token id of the minted Blobert
    fn mint_arcade_unlock(ref self: TContractState, attempt_id: felt252) -> u256;
}

#[starknet::interface]
trait IAmmaBlobertFighters {
    /// Creates a new fighter with the given attributes
    /// # Arguments
    /// * `name` - Name of the fighter
    /// * `stats` - Base statistics of the fighter
    /// * `generated_stats` - stats of the fighter used when generating
    /// * `attacks` - Array of attacks available to the fighter either a tag, attack input or attack
    /// id # Returns
    /// * `u32` - ID of the newly created fighter
    ///
    /// Models:
    /// * AmmaFighter
    ///
    /// Events:
    /// * AmmaFighterName
    fn new_fighter(
        ref self: TContractState,
        name: ByteArray,
        stats: UStats,
        generated_stats: UStats,
        attacks: Array<IdTagNew<AttackInput>>,
    ) -> u32;

    /// Updates an existing fighter's attributes
    /// # Arguments
    /// * `fighter` - ID of the fighter to update
    /// * `name` - New name for the fighter
    /// * `stats` - New base statistics for the fighter
    /// * `generated_stats` - New generated statistics for the fighter
    /// * `attacks` - Array of attacks available to the fighter either a tag, attack input or attack
    /// id
    ///
    /// Models:
    /// * AmmaFighter
    ///
    /// Events:
    /// * AmmaFighterName
    fn set_fighter(
        ref self: TContractState,
        fighter: u32,
        name: ByteArray,
        stats: UStats,
        generated_stats: UStats,
        attacks: Array<IdTagNew<AttackInput>>,
    );

    /// Updates a fighter's base statistics
    /// # Arguments
    /// * `fighter` - ID of the fighter to update
    /// * `stats` - New statistics to set
    ///
    /// Models:
    /// * AmmaFighter
    fn set_fighter_stats(ref self: TContractState, fighter: u32, stats: UStats);

    /// Updates a fighter's generated statistics
    /// # Arguments
    /// * `fighter` - ID of the fighter to update
    /// * `stats` - New generated statistics to set
    ///
    /// Models:
    /// * AmmaFighter
    fn set_fighter_generated_stats(ref self: TContractState, fighter: u32, stats: UStats);

    /// Updates a fighter's available attacks
    /// # Arguments
    /// * `fighter` - ID of the fighter to update
    /// * `attacks` - New array of attacks to set
    ///
    /// Models:
    /// * AmmaFighter
    fn set_fighter_attacks(
        ref self: TContractState, fighter: u32, attacks: Array<IdTagNew<AttackInput>>,
    );

    /// Updates a fighter's name
    /// # Arguments
    /// * `fighter` - ID of the fighter to update
    /// * `name` - New name to set
    ///
    /// Events:
    /// * AmmaFighterName
    fn set_fighter_name(ref self: TContractState, fighter: u32, name: ByteArray);

    /// Gets the total number of fighters
    /// # Returns
    /// * `u32` - Total number of fighters
    fn amount_of_fighters(self: @TContractState) -> u32;

    /// Sets the total number of fighters
    /// # Arguments
    /// * `amount` - New total number of fighters to set
    fn set_amount_of_fighters(ref self: TContractState, amount: u32);
}


fn get_amount_of_fighters(contract_address: ContractAddress) -> u32 {
    IAmmaBlobertFightersDispatcher { contract_address }.amount_of_fighters()
}

#[dojo::contract]
mod amma_blobert_actions {
    use core::poseidon::poseidon_hash_span;
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use starknet::storage::Map;
    use dojo::world::{WorldStorage, IWorldDispatcher};

    use crate::world::WorldTrait;
    use crate::starknet::return_value;
    use crate::permissions::{Role, Permissions};
    use crate::stats::UStats;
    use crate::collections;
    use crate::world::uuid;
    use crate::attacks::{AttackInput, AttackTrait};
    use crate::tags::IdTagNew;
    use crate::hash::hash_value;
    use crate::arcade_amma::{AmmaArcadeStorage};
    use crate::arcade::ArcadePhase;
    use super::super::{AmmaBlobertStorage, AmmaBlobertTrait, AMMA_BLOBERT_NAMESPACE_HASH};
    use collections::world_blobert::{WorldBlobertStore, WorldBlobertStorage};
    use collections::items::cmp;
    use collections::ICollection;
    use collections::{
        IBlobertCollectionImpl, TokenAttributes, CollectionGroupStorage, CollectionGroup,
        BlobertItemKey,
    };
    use super::{IAmmaBlobert, IAmmaBlobertFighters};
    const STARTER_TOKENS: [felt252; 2] = [4, 5];

    #[storage]
    struct Storage {
        fighters: u32,
        // fighter_numbers: Map<felt252, u32>,
    // fighter_ids: Map<u32, felt252>,
    }

    fn dojo_init(ref self: ContractState) {
        let mut storage = self.default_storage();
        storage.set_collection_group(get_contract_address(), CollectionGroup::AmmaBlobert);
    }

    impl AmmaBlobertStoreImpl =
        WorldBlobertStore<AMMA_BLOBERT_NAMESPACE_HASH, AMMA_BLOBERT_NAMESPACE_HASH>;

    #[abi(embed_v0)]
    impl IAmmaBlobertCollectionImpl of ICollection<ContractState> {
        fn owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
            self.storage(AMMA_BLOBERT_NAMESPACE_HASH).get_blobert_token_owner(token_id)
        }
        fn get_stats(self: @ContractState, token_id: u256) -> UStats {
            self.storage(AMMA_BLOBERT_NAMESPACE_HASH).get_amma_token_stats(token_id)
        }
        fn get_attack_slot(
            self: @ContractState, token_id: u256, item_id: felt252, slot: felt252,
        ) -> felt252 {
            self
                .storage(AMMA_BLOBERT_NAMESPACE_HASH)
                .get_amma_token_attack_slot(token_id, item_id, slot)
        }
        fn get_attack_slots(
            self: @ContractState, token_id: u256, item_slots: Array<(felt252, felt252)>,
        ) -> Array<felt252> {
            self
                .storage(AMMA_BLOBERT_NAMESPACE_HASH)
                .get_amma_token_attack_slots(token_id, item_slots)
        }
    }


    #[abi(embed_v0)]
    impl IAmmaBlobertImpl of IAmmaBlobert<ContractState> {
        fn mint_free(ref self: ContractState) -> Array<u256> {
            let mut storage = self.storage(AMMA_BLOBERT_NAMESPACE_HASH);
            let owner = get_caller_address();
            storage.assert_and_set_first_token_minted(owner);
            let mut token_ids: Array<u256> = Default::default();
            for fighter in STARTER_TOKENS.span() {
                let token_id = poseidon_hash_span([owner.into(), *fighter].span()).into();
                token_ids.append(token_id);
                storage.set_blobert_token(token_id, owner, TokenAttributes::Custom(*fighter));
            };
            return_value(token_ids)
        }

        fn mint_arcade_unlock(ref self: ContractState, attempt_id: felt252) -> u256 {
            let mut storage = self.storage(AMMA_BLOBERT_NAMESPACE_HASH);
            let owner = get_caller_address();
            let attempt = storage.get_amma_arcade_challenge_attempt_unlock_token(attempt_id);
            let token_id = poseidon_hash_span([attempt_id, 'token-unlock'].span());
            assert(attempt.player == owner, 'Not the players attempt');
            assert(attempt.phase == ArcadePhase::PlayerWon, 'Not a winner');
            storage.assert_and_set_arcade_attempt_minted(attempt_id);
            storage
                .set_blobert_token(
                    token_id.into(),
                    owner,
                    TokenAttributes::Custom(attempt.token_id.try_into().unwrap()),
                );
            return_value(token_id.into())
        }
    }
    #[abi(embed_v0)]
    impl IAmmaBlobertFightersImpl of IAmmaBlobertFighters<ContractState> {
        fn new_fighter(
            ref self: ContractState,
            name: ByteArray,
            stats: UStats,
            generated_stats: UStats,
            attacks: Array<IdTagNew<AttackInput>>,
        ) -> u32 {
            let mut storage = self.storage(AMMA_BLOBERT_NAMESPACE_HASH);
            storage.assert_caller_has_permission(Role::AmmaBlobertAdmin);
            let fighter = self.fighters.read() + 1;
            let attack_ids = storage.create_or_get_attacks_external(attacks);
            self.fighters.write(fighter);
            storage.set_amma_fighter(fighter, name, stats, generated_stats, attack_ids.len());
            storage.fill_amma_fighter_attack_slots(fighter, attack_ids);
            return_value(fighter)
        }
        fn set_fighter(
            ref self: ContractState,
            fighter: u32,
            name: ByteArray,
            stats: UStats,
            generated_stats: UStats,
            attacks: Array<IdTagNew<AttackInput>>,
        ) {
            let mut storage = self.storage(AMMA_BLOBERT_NAMESPACE_HASH);
            storage.assert_caller_has_permission(Role::AmmaBlobertAdmin);
            let attack_ids = storage.create_or_get_attacks_external(attacks);
            storage.set_amma_fighter(fighter, name, stats, generated_stats, attack_ids.len());
            storage.fill_amma_fighter_attack_slots(fighter, attack_ids);
        }
        fn set_fighter_stats(ref self: ContractState, fighter: u32, stats: UStats) {
            let mut storage = self.storage(AMMA_BLOBERT_NAMESPACE_HASH);
            storage.assert_caller_has_permission(Role::AmmaBlobertAdmin);
            storage.set_amma_fighter_stats(fighter, stats);
        }
        fn set_fighter_generated_stats(ref self: ContractState, fighter: u32, stats: UStats) {
            let mut storage = self.storage(AMMA_BLOBERT_NAMESPACE_HASH);
            storage.assert_caller_has_permission(Role::AmmaBlobertAdmin);
            storage.set_amma_fighter_generated_stats(fighter, stats);
        }
        fn set_fighter_attacks(
            ref self: ContractState, fighter: u32, attacks: Array<IdTagNew<AttackInput>>,
        ) {
            let mut storage = self.storage(AMMA_BLOBERT_NAMESPACE_HASH);
            storage.assert_caller_has_permission(Role::AmmaBlobertAdmin);
            let attack_ids = storage.create_or_get_attacks_external(attacks);
            storage.set_amma_fighter_attacks(fighter, attack_ids.len());
            storage.fill_amma_fighter_attack_slots(fighter, attack_ids);
        }
        fn set_fighter_name(ref self: ContractState, fighter: u32, name: ByteArray) {
            let mut storage = self.storage(AMMA_BLOBERT_NAMESPACE_HASH);
            storage.assert_caller_has_permission(Role::AmmaBlobertAdmin);
            storage.set_amma_fighter_name(fighter, name);
        }

        fn amount_of_fighters(self: @ContractState) -> u32 {
            self.fighters.read()
        }

        fn set_amount_of_fighters(ref self: ContractState, amount: u32) {
            let mut storage = self.storage(AMMA_BLOBERT_NAMESPACE_HASH);
            storage.assert_caller_has_permission(Role::AmmaBlobertAdmin);
            self.fighters.write(amount);
        }
    }
}

