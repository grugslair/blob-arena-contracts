use ba_arcade::Opponent;
use ba_blobert::TokenTraits;
use ba_loadout::Attributes;
use ba_loadout::action::IdTagAction;
use ba_utils::storage::{FeltArrayReadWrite, ShortArrayStore};

/// Storage and query structure for classic arcade opponents
///
/// Represents a fully configured opponent stored in the contract state for classic arcade mode.
/// Contains resolved action IDs and complete attribute sets for immediate use in combat.
///
/// # Fields
/// * `traits` - Token traits that define the opponent's visual and thematic characteristics
/// * `attributes` - Complete attribute set including abilities, resistances, and vulnerabilities
/// * `actions` - Array of resolved action IDs available to this opponent
#[derive(Drop, Serde, Introspect)]
struct OpponentTable {
    traits: TokenTraits,
    attributes: Attributes,
    actions: Array<felt252>,
}

/// Input structure for configuring classic arcade opponents
///
/// Used when setting up the fixed opponent sequence for classic arcade mode.
/// Contains raw action definitions that will be processed into action IDs during setup.
///
/// # Fields
/// * `traits` - Token traits for the opponent's appearance and characteristics
/// * `attributes` - Complete attribute configuration for this opponent
/// * `actions` - Array of action definitions that will be resolved to action IDs
#[derive(Drop, Serde)]
struct OpponentInput {
    traits: TokenTraits,
    attributes: Attributes,
    actions: Array<IdTagAction>,
}


mod errors {
    pub const RESPAWN_WHEN_NOT_LOST: felt252 = 'Cannot respawn, player not lost';
    pub const NOT_ACTIVE: felt252 = 'Combat is not active';
    pub const MAX_RESPAWNS_REACHED: felt252 = 'Max respawns reached';
}

#[starknet::interface]
trait IArcadeClassic<TState> {
    /// Sets the complete opponent sequence for the classic arcade
    ///
    /// Replaces the entire opponent roster with a new fixed sequence.
    /// The number of opponents determines the total number of stages in the arcade.
    ///
    /// # Arguments
    /// * `opponents` - Array of opponent configurations in stage order
    fn set_opponents(ref self: TState, opponents: Array<OpponentInput>);
}

#[starknet::contract]
mod arcade_classic {
    use ba_arcade::attempt::{ArcadeProgress, AttemptNodePath, AttemptNodeTrait};
    use ba_arcade::{IArcade, arcade_component};
    use ba_combat::Move;
    use ba_combat::systems::get_action_dispatcher_address;
    use ba_loadout::action::interface::maybe_create_actions_array;
    use ba_utils::vrf::vrf_component;
    use beacon_library::{ToriiTable, register_table_with_schema};
    use sai_ownable::{OwnableTrait, ownable_component};
    use sai_return::emit_return;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ClassHash, ContractAddress};
    use crate::{Attributes, Opponent, TokenTraits};
    use super::{IArcadeClassic, IdTagAction, OpponentInput};

    component!(path: ownable_component, storage: ownable, event: OwnableEvents);
    component!(path: arcade_component, storage: arcade, event: ArcadeEvents);
    component!(path: vrf_component, storage: vrf, event: VrfEvents);

    const ATTEMPT_HASH: felt252 = bytearrays_hash!("arcade_classic", "Attempt");
    const COMBAT_HASH: felt252 = bytearrays_hash!("arcade_classic", "Combat");
    const ROUND_HASH: felt252 = bytearrays_hash!("arcade_classic", "Round");
    const LAST_USED_ATTACK_HASH: felt252 = bytearrays_hash!("arcade_classic", "ActionLastUsed");
    const OPPONENT_HASH: felt252 = bytearrays_hash!("arcade_classic", "Opponent");

    impl OpponentTable = ToriiTable<OPPONENT_HASH>;

    impl ArcadeInternal =
        arcade_component::ArcadeInternal<
            ContractState, ATTEMPT_HASH, COMBAT_HASH, ROUND_HASH, LAST_USED_ATTACK_HASH,
        >;
    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: ownable_component::Storage,
        #[substorage(v0)]
        arcade: arcade_component::Storage,
        #[substorage(v0)]
        vrf: vrf_component::Storage,
        opponents: Map<u32, Opponent>,
        stages_len: u32,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvents: ownable_component::Event,
        #[flat]
        ArcadeEvents: arcade_component::Event,
        #[flat]
        VrfEvents: vrf_component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        arcade_round_result_class_hash: ClassHash,
        action_address: ContractAddress,
        loadout_address: ContractAddress,
        orb_address: ContractAddress,
    ) {
        self.grant_owner(owner);
        ArcadeInternal::init(
            ref self.arcade,
            "arcade_classic",
            arcade_round_result_class_hash,
            action_address,
            loadout_address,
            orb_address,
        );
        register_table_with_schema::<super::OpponentTable>("arcade_classic", "Opponent");
    }

    #[abi(embed_v0)]
    impl IOwnableImpl = ownable_component::OwnableImpl<ContractState>;

    #[abi(embed_v0)]
    impl IVrfImpl = vrf_component::VrfImpl<ContractState>;

    #[abi(embed_v0)]
    impl IArcadeImpl of IArcade<ContractState> {
        fn start(
            ref self: ContractState,
            collection_address: ContractAddress,
            token_id: u256,
            action_slots: Array<Array<felt252>>,
        ) -> felt252 {
            let (mut attempt_ptr, attempt_id, _) = ArcadeInternal::start_attempt(
                ref self.arcade, collection_address, token_id, action_slots,
            );

            self.new_combat(ref attempt_ptr, attempt_id, 0, 0, None);
            emit_return(attempt_id)
        }

        fn act(ref self: ContractState, attempt_id: felt252, action: Move) {
            let (mut attempt_ptr, result, mut randomness) = ArcadeInternal::act_attempt(
                ref self.arcade, attempt_id, action,
            );
            if result.phase == ArcadeProgress::PlayerWon {
                ArcadeInternal::get_stage_reward(
                    ref self.arcade, result.player, result.stage, ref randomness,
                );
                let next_stage = result.stage + 1;
                if next_stage == self.stages_len.read() {
                    ArcadeInternal::set_phase(
                        ref attempt_ptr, attempt_id, ArcadeProgress::PlayerWon,
                    );
                    ArcadeInternal::get_challenge_reward(
                        ref self.arcade, result.player, ref randomness,
                    );
                } else if attempt_ptr.is_not_expired() {
                    attempt_ptr.stage.write(next_stage);
                    let health = result.health;
                    self
                        .new_combat(
                            ref attempt_ptr,
                            attempt_id,
                            result.combat_n + 1,
                            next_stage,
                            Some(health),
                        );
                } else {
                    ArcadeInternal::set_loss(ref self.arcade, ref attempt_ptr, attempt_id);
                }
            }
        }

        fn respawn(ref self: ContractState, attempt_id: felt252) {
            let (mut attempt_ptr, combat_n, stage) = ArcadeInternal::respawn_attempt(
                ref self.arcade, attempt_id,
            );
            self.new_combat(ref attempt_ptr, attempt_id, combat_n + 1, stage, None);
        }

        fn forfeit(ref self: ContractState, attempt_id: felt252) {
            ArcadeInternal::forfeit_attempt(ref self.arcade, attempt_id);
        }
    }

    #[abi(embed_v0)]
    impl IArcadeSettings = arcade_component::ArcadeSettingsImpl<ContractState>;

    #[abi(embed_v0)]
    impl IArcadeClassicImpl of IArcadeClassic<ContractState> {
        fn set_opponents(ref self: ContractState, opponents: Array<OpponentInput>) {
            self.assert_caller_is_owner();
            self.stages_len.write(opponents.len());
            let mut all_actions: Array<Array<IdTagAction>> = Default::default();
            let mut attributes: Array<(TokenTraits, Attributes)> = Default::default();
            for opponent in opponents {
                all_actions.append(opponent.actions);
                attributes.append((opponent.traits, opponent.attributes));
            }
            let all_action_ids = maybe_create_actions_array(
                get_action_dispatcher_address(), all_actions,
            );
            for (i, ((traits, attr), actions)) in attributes
                .into_iter()
                .zip(all_action_ids)
                .enumerate() {
                OpponentTable::set_entity(i, @(traits, attr, actions.span()));
                self.opponents.write(i, Opponent { attributes: attr, actions });
            }
        }
    }


    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn new_combat(
            ref self: ContractState,
            ref attempt_ptr: AttemptNodePath,
            attempt_id: felt252,
            combat_n: u32,
            stage: u32,
            health: Option<u8>,
        ) {
            ArcadeInternal::new_combat(
                ref self.arcade,
                ref attempt_ptr,
                attempt_id,
                combat_n,
                stage,
                self.opponents.read(stage).into(),
                health,
            );
        }
    }
}
