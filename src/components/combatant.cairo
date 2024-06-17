use core::traits::Into;
use core::array::ArrayTrait;
use core::clone::Clone;
use alexandria_data_structures::array_ext::ArrayTraitExt;
use starknet::{ContractAddress, get_caller_address};
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};
use blob_arena::{
    core::{U8ArrayCopyImpl, U128ArrayCopyImpl},
    components::{
        stats::Stats, attack::{Attack, AttackIdsImpl, IdsTrait, AttackTrait},
        //  stats::Stats, attack::{Attack, IdsTrait, IdTrait, AttackTrait}, 
        warrior::{Warrior, WarriorTrait}, item::{Item, ItemsTrait, ItemArrayCopyImpl}
    },
    models::{CombatantInfo, CombatantAttributes, CombatantState},
};


#[derive(Drop, Serde, Copy)]
struct Combatant {
    combat_id: u128,
    warrior_id: u128,
    stats: Stats,
    health: u8,
    attacks: Span<u128>,
    stun_chances: Array<u8>,
}

#[derive(Drop, Serde, Copy)]
struct Attacker {
    combat_id: u128,
    warrior_id: u128,
    stats: Stats,
    attacks: Span<u128>,
    stun_chances: Array<u8>,
}
#[derive(Drop, Serde, Copy)]
struct Defender {
    combat_id: u128,
    warrior_id: u128,
    health: u8,
    stun_chances: Array<u8>,
}

impl CombatantIntoAttacker of Into<Combatant, Attacker> {
    fn into(self: Combatant) -> Attacker {
        Attacker {
            combat_id: self.combat_id,
            warrior_id: self.warrior_id,
            stats: self.stats,
            attacks: self.attacks,
            stun_chances: self.stun_chances,
        }
    }
}
impl CombatantIntoDefender of Into<Combatant, Defender> {
    fn into(self: Combatant) -> Defender {
        Defender {
            combat_id: self.combat_id,
            warrior_id: self.warrior_id,
            health: self.health,
            stun_chances: self.stun_chances,
        }
    }
}

impl CombatantIntoCombatantState of Into<Combatant, CombatantState> {
    fn into(self: Combatant) -> CombatantState {
        CombatantState {
            combat_id: self.combat_id,
            warrior_id: self.warrior_id,
            health: self.health,
            stun_chances: self.stun_chances,
        }
    }
}

#[generate_trait]
impl CombatantImpl of CombatantTrait {
    fn get_combatant(self: IWorldDispatcher, combat_id: u128, warrior_id: u128) -> Combatant {
        let combatant_state = self.get_combatant_state(combat_id, warrior_id);
        let combatant_attributes = self.get_combatant_attributes(combat_id, warrior_id);
        Combatant {
            combat_id,
            warrior_id,
            stats: combatant_attributes.stats,
            health: combatant_state.health,
            stun_chances: combatant_state.stun_chances,
            attacks: combatant_attributes.attacks.span(),
        }
    }
    fn get_combatant_info(
        self: IWorldDispatcher, combat_id: u128, warrior_id: u128
    ) -> CombatantInfo {
        get!(self, (combat_id, warrior_id), CombatantInfo)
    }

    fn get_combatant_state(
        self: IWorldDispatcher, combat_id: u128, warrior_id: u128
    ) -> CombatantState {
        get!(self, (combat_id, warrior_id), CombatantState)
    }

    fn get_combatant_attributes(
        self: IWorldDispatcher, combat_id: u128, warrior_id: u128
    ) -> CombatantAttributes {
        get!(self, (combat_id, warrior_id), CombatantAttributes)
    }

    fn create_combatant(
        self: IWorldDispatcher, warrior: Warrior, combat_id: u128
    ) -> CombatantInfo {
        let items = warrior.items.span();
        let combatant_info = CombatantInfo {
            combat_id, warrior_id: warrior.id, player: warrior.owner,
        };
        let combatant_state = CombatantState {
            combat_id,
            warrior_id: warrior.id,
            health: items.get_health(),
            stun_chances: ArrayTrait::new(),
        };
        let combatant_attributes = CombatantAttributes {
            combat_id,
            warrior_id: warrior.id,
            stats: items.get_stats(),
            attacks: items.get_attack_ids(),
        };
        set!(self, (combatant_info, combatant_state, combatant_attributes,));
        combatant_info
    }

    fn get_player_combatant_info(
        self: IWorldDispatcher, combat_id: u128, warrior_id: u128
    ) -> CombatantInfo {
        let combatant = self.get_combatant_info(combat_id, warrior_id);
        let caller = get_caller_address();
        assert(caller == combatant.player, 'Not combatant player');
        combatant
    }

    fn has_attack(self: CombatantAttributes, attack_id: u128) -> bool {
        let (len, mut n) = (self.attacks.len(), 0_usize);
        let mut has_attack = false;
        self.attacks.contains(attack_id)
    }

    fn assert_player(self: CombatantInfo) -> ContractAddress {
        assert(get_caller_address() == self.player, 'Not combatant player'); //#
        self.player
    }
}
