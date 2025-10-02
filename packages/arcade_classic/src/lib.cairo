use ba_arcade::Opponent;
use ba_blobert::TokenTraits;
use ba_loadout::Attributes;
use ba_loadout::attack::IdTagAttack;
use ba_utils::storage::{FeltArrayReadWrite, ShortArrayStore};

#[derive(Drop, Serde, Introspect)]
struct OpponentTable {
    traits: TokenTraits,
    attributes: Attributes,
    attacks: Array<felt252>,
}

#[derive(Drop, Serde)]
struct OpponentInput {
    traits: TokenTraits,
    attributes: Attributes,
    attacks: Array<IdTagAttack>,
}

mod errors {
    pub const RESPAWN_WHEN_NOT_LOST: felt252 = 'Cannot respawn, player not lost';
    pub const NOT_ACTIVE: felt252 = 'Combat is not active';
    pub const MAX_RESPAWNS_REACHED: felt252 = 'Max respawns reached';
}

#[starknet::interface]
trait IArcadeClassic<TState> {
    fn set_opponents(ref self: TState, opponents: Array<OpponentInput>);
}

#[starknet::contract]
mod arcade_classic {
    use ba_arcade::attempt::{ArcadeProgress, AttemptNodePath, AttemptNodeTrait};
    use ba_arcade::{IArcade, arcade_component};
    use ba_combat::systems::get_attack_dispatcher_address;
    use ba_loadout::attack::interface::maybe_create_attacks_array;
    use beacon_library::{ToriiTable, register_table_with_schema};
    use sai_ownable::{OwnableTrait, ownable_component};
    use sai_return::emit_return;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ClassHash, ContractAddress};
    use crate::Opponent;
    use super::{IArcadeClassic, IdTagAttack, OpponentInput};

    component!(path: ownable_component, storage: ownable, event: OwnableEvents);
    component!(path: arcade_component, storage: arcade, event: ArcadeEvents);

    const ATTEMPT_HASH: felt252 = bytearrays_hash!("arcade_classic", "ArcadeAttempt");
    const ROUND_HASH: felt252 = bytearrays_hash!("arcade_classic", "ArcadeRound");
    const LAST_USED_ATTACK_HASH: felt252 = bytearrays_hash!("arcade_classic", "AttackLastUsed");
    const OPPONENT_HASH: felt252 = bytearrays_hash!("arcade_classic", "Opponent");

    impl OpponentTable = ToriiTable<OPPONENT_HASH>;

    impl ArcadeInternal =
        arcade_component::ArcadeInternal<
            ContractState, ATTEMPT_HASH, ROUND_HASH, LAST_USED_ATTACK_HASH,
        >;
    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: ownable_component::Storage,
        #[substorage(v0)]
        arcade: arcade_component::Storage,
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
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        arcade_round_result_class_hash: ClassHash,
        attack_address: ContractAddress,
        loadout_address: ContractAddress,
        credit_address: ContractAddress,
        vrf_address: ContractAddress,
    ) {
        self.grant_owner(owner);
        ArcadeInternal::init(
            ref self.arcade,
            "arcade_classic",
            arcade_round_result_class_hash,
            attack_address,
            loadout_address,
            credit_address,
            vrf_address,
        );
        register_table_with_schema::<super::OpponentTable>("arcade_classic", "Opponent");
    }

    #[abi(embed_v0)]
    impl IOwnableImpl = ownable_component::OwnableImpl<ContractState>;

    #[abi(embed_v0)]
    impl IArcadeImpl of IArcade<ContractState> {
        fn start(
            ref self: ContractState,
            collection_address: ContractAddress,
            token_id: u256,
            attack_slots: Array<Array<felt252>>,
        ) -> felt252 {
            let (mut attempt_ptr, attempt_id, _) = ArcadeInternal::start_attempt(
                ref self.arcade, collection_address, token_id, attack_slots,
            );

            self.new_combat(ref attempt_ptr, attempt_id, 0, 0, None);
            emit_return(attempt_id)
        }

        fn attack(ref self: ContractState, attempt_id: felt252, attack_id: felt252) {
            let (mut attempt_ptr, result, _) = ArcadeInternal::attack_attempt(
                ref self.arcade, attempt_id, attack_id,
            );
            if result.phase == ArcadeProgress::PlayerWon {
                let next_stage = result.stage + 1;
                if next_stage == self.stages_len.read() {
                    ArcadeInternal::set_phase(
                        ref attempt_ptr, attempt_id, ArcadeProgress::PlayerWon,
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
            let mut all_attacks: Array<Array<IdTagAttack>> = Default::default();
            for opponent in opponents.span() {
                all_attacks.append(opponent.attacks.clone());
            }
            let all_attack_ids = maybe_create_attacks_array(
                get_attack_dispatcher_address(), all_attacks,
            );
            for (i, (opponent, attacks)) in opponents.into_iter().zip(all_attack_ids).enumerate() {
                OpponentTable::set_entity(
                    i, @(opponent.traits, opponent.attributes, attacks.span()),
                );
                self.opponents.write(i, Opponent { attributes: opponent.attributes, attacks });
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
                self.opponents.read(stage).into(),
                health,
            );
        }
    }
}
