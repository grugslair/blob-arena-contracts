use ba_loadout::PartialAttributes;


#[derive(Drop, Serde)]
struct OpponentAttributesInput {
    fighter: u32,
    base: PartialAttributes,
    level: PartialAttributes,
}

#[derive(Drop, Introspect)]
struct OpponentAttributesTable {
    base: PartialAttributes,
    level: PartialAttributes,
}

#[starknet::interface]
trait IArcadeAmma<TState> {
    fn gen_stages(self: @TState) -> u32;
    fn set_gen_stages(ref self: TState, gen_stages: u32);
    fn set_opponent_attributes(
        ref self: TState, fighter: u32, base: PartialAttributes, level: PartialAttributes,
    );
    fn set_opponents_attributes(ref self: TState, opponents: Array<OpponentAttributesInput>);
    fn set_opponent_count(ref self: TState, count: u32);
}

#[starknet::contract]
mod arcade_amma {
    use ba_arcade::attempt::{ArcadePhase, AttemptNodeTrait};
    use ba_arcade::{IArcade, Opponent, arcade_component};
    use ba_loadout::PartialAttributes;
    use ba_loadout::attributes::AttributesCalcTrait;
    use ba_loadout::loadout_amma::{get_fighter_attacks, get_fighter_count, get_fighter_loadout};
    use ba_utils::{CapInto, Randomness, RandomnessTrait};
    use beacon_library::{ToriiTable, register_table_with_schema};
    use sai_core_utils::poseidon_hash_two;
    use sai_ownable::{OwnableTrait, ownable_component};
    use sai_return::emit_return;
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use crate::systems::{attack_slots, random_selection};
    use super::{IArcadeAmma, OpponentAttributesInput};

    component!(path: ownable_component, storage: ownable, event: OwnableEvents);
    component!(path: arcade_component, storage: arcade, event: ArcadeEvents);

    const ROUND_HASH: felt252 = bytearrays_hash!("arcade_amma", "ArcadeRound");
    const ATTEMPT_HASH: felt252 = bytearrays_hash!("arcade_amma", "ArcadeAttempt");
    const LAST_USED_ATTACK_HASH: felt252 = bytearrays_hash!("arcade_amma", "AttackLastUsed");
    const OPPONENTS_HASH: felt252 = bytearrays_hash!("arcade_amma", "Opponents");
    const OPPONENTS_ATTRIBUTES_HASH: felt252 = bytearrays_hash!(
        "arcade_amma", "OpponentAttributes",
    );

    impl OpponentsTable = ToriiTable<OPPONENTS_HASH>;
    impl ArcadeInternal =
        arcade_component::ArcadeInternal<
            ContractState, ATTEMPT_HASH, ROUND_HASH, LAST_USED_ATTACK_HASH,
        >;
    impl OpponentsAttributesTable = ToriiTable<OPPONENTS_ATTRIBUTES_HASH>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: ownable_component::Storage,
        #[substorage(v0)]
        arcade: arcade_component::Storage,
        collectable_address: ContractAddress,
        gen_stages: u32,
        opponents_attributes: Map<u32, (PartialAttributes, PartialAttributes)>,
        opponent_count: u32,
        opponents: Map<felt252, u32>,
        bosses: Map<felt252, u32>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvents: ownable_component::Event,
        #[flat]
        ArcadeEvents: arcade_component::Event,
    }

    #[derive(Drop, Serde, Introspect)]
    struct Opponents {
        generated: Array<u32>,
        boss: u32,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        attack_address: ContractAddress,
        loadout_address: ContractAddress,
        credit_address: ContractAddress,
        vrf_address: ContractAddress,
        collectable_address: ContractAddress,
    ) {
        self.grant_owner(owner);
        ArcadeInternal::init(
            ref self.arcade,
            "arcade_amma",
            attack_address,
            loadout_address,
            credit_address,
            vrf_address,
        );
        register_table_with_schema::<Opponents>("arcade_amma", "Opponents");
        register_table_with_schema::<
            super::OpponentAttributesTable,
        >("arcade_amma", "OpponentAttributes");
        self.collectable_address.write(collectable_address);
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
            let (mut attempt_ptr, attempt_id, loadout_address) = ArcadeInternal::start_attempt(
                ref self.arcade, collection_address, token_id, attack_slots,
            );
            let mut randomness = ArcadeInternal::consume_randomness(ref self.arcade, attempt_id);
            let opponents = random_selection(
                ref randomness, self.opponent_count.read(), self.gen_stages.read(),
            );
            ArcadeInternal::new_combat(
                ref self.arcade,
                ref attempt_ptr,
                attempt_id,
                0,
                self.gen_opponent(loadout_address, *opponents[0], 0),
                None,
            );
            OpponentsTable::set_entity(attempt_id, @(opponents.span(), 0));
            for (i, opponent) in opponents.into_iter().enumerate() {
                self.opponents.write(poseidon_hash_two(attempt_id, i), opponent);
            }

            emit_return(attempt_id)
        }

        fn attack(ref self: ContractState, attempt_id: felt252, attack_id: felt252) {
            let (mut attempt_ptr, result, mut randomness) = ArcadeInternal::attack_attempt(
                ref self.arcade, attempt_id, attack_id,
            );

            if result.phase == ArcadePhase::PlayerWon {
                let next_stage = result.stage + 1;
                let gen_stages = self.gen_stages.read();
                if next_stage == gen_stages + 1 {
                    ArcadeInternal::set_phase(ref attempt_ptr, attempt_id, ArcadePhase::PlayerWon);
                } else if attempt_ptr.is_not_expired() {
                    attempt_ptr.stage.write(next_stage);
                    let health = result.health;
                    let loadout_address = self.arcade.loadout_address.read();
                    let opponent = match next_stage == gen_stages {
                        true => self.gen_boss_opponent(attempt_id, ref randomness),
                        false => self.gen_opponent_stage(loadout_address, attempt_id, next_stage),
                    };

                    ArcadeInternal::new_combat(
                        ref self.arcade,
                        ref attempt_ptr,
                        attempt_id,
                        result.combat_n + 1,
                        opponent,
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

            let opponent = match stage == self.gen_stages.read() {
                true => self.read_boss_opponent(attempt_id),
                false => self
                    .gen_opponent_stage(self.arcade.loadout_address.read(), attempt_id, stage),
            };

            ArcadeInternal::new_combat(
                ref self.arcade, ref attempt_ptr, attempt_id, combat_n + 1, opponent, None,
            );
        }


        fn forfeit(ref self: ContractState, attempt_id: felt252) {
            ArcadeInternal::forfeit_attempt(ref self.arcade, attempt_id);
        }
    }

    #[abi(embed_v0)]
    impl IArcadeSettings = arcade_component::ArcadeSettingsImpl<ContractState>;

    #[abi(embed_v0)]
    impl IArcadeAmmaImpl of IArcadeAmma<ContractState> {
        fn gen_stages(self: @ContractState) -> u32 {
            self.gen_stages.read()
        }

        fn set_gen_stages(ref self: ContractState, gen_stages: u32) {
            self.assert_caller_is_owner();
            self.gen_stages.write(gen_stages);
        }

        fn set_opponent_attributes(
            ref self: ContractState,
            fighter: u32,
            base: PartialAttributes,
            level: PartialAttributes,
        ) {
            self.assert_caller_is_owner();
            self.set_opponent_attributes_internal(fighter, base, level);
        }

        fn set_opponents_attributes(
            ref self: ContractState, opponents: Array<OpponentAttributesInput>,
        ) {
            self.assert_caller_is_owner();
            for opponent in opponents {
                self
                    .set_opponent_attributes_internal(
                        opponent.fighter, opponent.base, opponent.level,
                    );
            }
        }

        fn set_opponent_count(ref self: ContractState, count: u32) {
            self.assert_caller_is_owner();
            self.opponent_count.write(count);
        }
    }


    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn gen_opponent_stage(
            self: @ContractState, loadout_address: ContractAddress, attempt_id: felt252, stage: u32,
        ) -> Opponent {
            self
                .gen_opponent(
                    loadout_address,
                    self.opponents.read(poseidon_hash_two(attempt_id, stage)),
                    stage,
                )
        }

        fn set_opponent_attributes_internal(
            ref self: ContractState,
            fighter: u32,
            base: PartialAttributes,
            level: PartialAttributes,
        ) {
            self.opponents_attributes.write(fighter, (base, level));
            OpponentsAttributesTable::set_entity(fighter, @(base, level));
        }

        fn gen_opponent(
            self: @ContractState, loadout_address: ContractAddress, fighter: u32, stage: u32,
        ) -> Opponent {
            let attacks = get_fighter_attacks(loadout_address, fighter, attack_slots());
            let (base, level) = self.opponents_attributes.read(fighter);
            let attributes = (level.into().mul(stage.cap_into(10)) + base.into()).finalize();
            Opponent { attributes, attacks: attacks.span() }
        }

        fn gen_boss_opponent(
            ref self: ContractState, attempt_id: felt252, ref randomness: Randomness,
        ) -> Opponent {
            let loadout_address = self.arcade.loadout_address.read();
            let count = get_fighter_count(loadout_address);
            let fighter: u32 = randomness.final(count) + 1;

            OpponentsTable::set_member(selector!("boss"), attempt_id, @fighter);
            self.bosses.write(attempt_id, fighter);
            self.boss_opponent(loadout_address, fighter)
        }

        fn read_boss_opponent(self: @ContractState, attempt_id: felt252) -> Opponent {
            let fighter = self.bosses.read(attempt_id);
            self.boss_opponent(self.arcade.loadout_address.read(), fighter)
        }

        fn boss_opponent(
            self: @ContractState, loadout_address: ContractAddress, fighter: u32,
        ) -> Opponent {
            let (attributes, attacks) = get_fighter_loadout(
                loadout_address, fighter, attack_slots(),
            );
            Opponent { attributes, attacks: attacks.span() }
        }
    }
}
