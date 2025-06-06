use starknet::ContractAddress;
use crate::permissions::Role;
use crate::achievements::TrophyCreationInput;
use crate::attacks::{Attack, AttackInput};
use crate::stats::UStats;
use crate::combatants::CombatantState;

#[starknet::interface]
trait IPermissions<TContractState> {
    /// Sets a role for a user
    ///
    /// * `user` - Address of the user to set role for
    /// * `role` - Role to be assigned
    /// * `has` - Boolean indicating if the role should be granted or revoked
    ///
    /// Models:
    /// - Permission
    fn set_has_role(ref self: TContractState, user: ContractAddress, role: Role, has: bool);

    /// Checks if a user has a specific role
    ///
    /// * `user` - Address of the user to check
    /// * `role` - Role to check for
    ///
    /// Returns: Boolean indicating if user has the role
    fn get_has_role(self: @TContractState, user: ContractAddress, role: Role) -> bool;

    /// Batch sets roles for multiple users
    ///
    /// * `users` - Array of user addresses
    /// * `role` - Role to be assigned to all users
    /// * `has` - Boolean indicating if the role should be granted or revoked
    ///
    /// Models:
    /// - Permission
    fn set_multiple_has_role(
        ref self: TContractState, users: Array<ContractAddress>, role: Role, has: bool,
    );
}

#[starknet::interface]
trait IAchievements<TContractState> {
    /// Creates new achievements
    ///
    /// * `achievements` - The achievements to be created
    ///
    /// Models:
    /// - AchievementCreation
    fn create_achievements(ref self: TContractState, achievements: Array<TrophyCreationInput>);

    /// Creates a new achievement
    ///
    /// * `achievement` - The achievement to be created
    ///
    /// Models:
    /// - AchievementCreation

    fn create_achievement(ref self: TContractState, achievement: TrophyCreationInput);
}

#[starknet::interface]
trait IAttacks<TContractState> {
    /// Reads an attack
    ///
    /// * `attack_id` - The ID of the attack to read
    ///
    /// Returns: The attack details
    fn attack(self: @TContractState, attack_id: felt252) -> Attack;
    /// Reads the attack ID
    ///
    /// * `attack` - The attack input to read
    ///
    /// Returns: The ID of the attack
    fn attack_id_from_input(self: @TContractState, attack: AttackInput) -> felt252;
    /// Reads when the attack was last used
    ///
    /// * `combatant_id` - The ID of the combatant
    /// * `attack_id` - The ID of the attack
    /// Returns: The last used round of the attack
    fn attack_last_used(self: @TContractState, combatant_id: felt252, attack_id: felt252) -> u32;
    /// Reads if the attack is available to the combatant
    ///
    /// * `combatant_id` - The ID of the combatant
    /// * `attack_id` - The ID of the attack
    /// Returns: Boolean indicating if the attack is available
    fn attack_available(self: @TContractState, combatant_id: felt252, attack_id: felt252) -> bool;
    /// Reads the attack cooldown
    ///
    /// * `attack_id` - The ID of the attack
    /// Returns: The cooldown of the attack
    fn attack_cooldown(self: @TContractState, attack_id: felt252) -> u8;
}

#[starknet::interface]
trait ICombatant<TContractState> {
    /// Returns the combatant state
    /// # Arguments
    /// * `combatant_id` - The unique identifier of the combatant to check
    /// # Returns
    /// * `CombatantState` - The state of the combatant
    fn combatant_state(self: @TContractState, combatant_id: felt252) -> CombatantState;
    /// Returns the combatant combat ID
    /// # Arguments
    /// * `combatant_id` - The unique identifier of the combatant to check
    /// # Returns
    /// * `felt252` - The combat ID of the combatant
    fn combatant_combat_id(self: @TContractState, combatant_id: felt252) -> felt252;
    /// Returns the combatant player address
    /// # Arguments
    /// * `combatant_id` - The unique identifier of the combatant to check
    /// # Returns
    /// * `ContractAddress` - The address of the combatant player
    fn combatant_player(self: @TContractState, combatant_id: felt252) -> ContractAddress;
    /// Returns the health of a specific combatant
    /// # Arguments
    /// * `combatant_id` - The unique identifier of the combatant to check
    /// # Returns
    /// * `u8` - The current health of the combatant
    fn combatant_health(self: @TContractState, combatant_id: felt252) -> u8;
    /// Returns the stats of a combatant
    /// # Arguments
    /// * `combatant_id` - The unique identifier of the combatant
    /// # Returns
    /// * `UStats` - The stats of the combatant
    fn combatant_stats(self: @TContractState, combatant_id: felt252) -> UStats;
    /// Returns the stun chance of a combatant
    /// # Arguments
    /// * `combatant_id` - The unique identifier of the combatant
    /// # Returns
    /// * `u8` - The stun chance as as value between 0 and 255
    fn combatant_stun_chance(self: @TContractState, combatant_id: felt252) -> u8;
}

#[dojo::contract]
mod game_actions {
    use dojo::world::WorldStorage;
    use starknet::{ContractAddress, get_tx_info};
    use crate::world::{WorldTrait, get_world_address};
    use crate::permissions::{Role, Permissions, Permission, PermissionStorage};
    use crate::achievements::{Achievements, TrophyCreationInput};
    use crate::attacks::{
        AttackStorage, Attack, AttackInput, AttackInputTrait, results::RoundResult,
    };
    use crate::combatants::{CombatantState, CombatantStorage};
    use crate::stats::UStats;

    use super::{IPermissions, IAchievements, IAttacks, ICombatant};

    fn dojo_init(ref self: ContractState) {
        let mut world = self.default_storage();

        let admin = get_tx_info().unbox().account_contract_address;
        world.set_permission(admin, Role::Admin, true);
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        RoundResult: RoundResult,
        CombatantState: CombatantState,
    }


    #[abi(embed_v0)]
    impl IPermissionsImpl of IPermissions<ContractState> {
        fn set_has_role(ref self: ContractState, user: ContractAddress, role: Role, has: bool) {
            let mut world = self.world_dispatcher();
            world.assert_caller_is_admin();
            world.set_permission(user, role, has);
        }

        fn get_has_role(self: @ContractState, user: ContractAddress, role: Role) -> bool {
            let world = self.world_dispatcher();
            world.get_permission(user, role)
        }

        fn set_multiple_has_role(
            ref self: ContractState, users: Array<ContractAddress>, role: Role, has: bool,
        ) {
            let mut world = self.world_dispatcher();
            world.assert_caller_is_admin();
            let mut permissions = ArrayTrait::<Permission>::new();
            for user in users {
                permissions.append(Permission { requester: user, role, has });
            };
            world.set_permissions(permissions);
        }
    }

    #[abi(embed_v0)]
    impl IAchievementsImpl of IAchievements<ContractState> {
        fn create_achievements(ref self: ContractState, achievements: Array<TrophyCreationInput>) {
            let mut world = self.world_dispatcher();
            world.assert_caller_has_permission(Role::AchievementSetter);
            world.create_achievements(achievements);
        }

        fn create_achievement(ref self: ContractState, achievement: TrophyCreationInput) {
            let mut world = self.world_dispatcher();
            world.assert_caller_has_permission(Role::AchievementSetter);
            world.create_achievement(achievement);
        }
    }

    #[abi(embed_v0)]
    impl IAttacksImpl of IAttacks<ContractState> {
        fn attack(self: @ContractState, attack_id: felt252) -> Attack {
            self.default_storage().get_attack(attack_id)
        }

        fn attack_id_from_input(self: @ContractState, attack: AttackInput) -> felt252 {
            attack.id()
        }

        fn attack_last_used(
            self: @ContractState, combatant_id: felt252, attack_id: felt252,
        ) -> u32 {
            self.default_storage().get_attack_last_used(combatant_id, attack_id)
        }

        fn attack_available(
            self: @ContractState, combatant_id: felt252, attack_id: felt252,
        ) -> bool {
            self.default_storage().check_attack_available(combatant_id, attack_id)
        }

        fn attack_cooldown(self: @ContractState, attack_id: felt252) -> u8 {
            self.default_storage().get_attack_cooldown(attack_id)
        }
    }

    #[abi(embed_v0)]
    impl ICombatantImpl of ICombatant<ContractState> {
        fn combatant_state(self: @ContractState, combatant_id: felt252) -> CombatantState {
            self.default_storage().get_combatant_state(combatant_id)
        }
        fn combatant_combat_id(self: @ContractState, combatant_id: felt252) -> felt252 {
            self.default_storage().get_combatant_combat_id(combatant_id)
        }

        fn combatant_player(self: @ContractState, combatant_id: felt252) -> ContractAddress {
            self.default_storage().get_player(combatant_id)
        }

        fn combatant_health(self: @ContractState, combatant_id: felt252) -> u8 {
            self.default_storage().get_combatant_health(combatant_id)
        }

        fn combatant_stats(self: @ContractState, combatant_id: felt252) -> UStats {
            self.default_storage().get_combatant_stats(combatant_id)
        }

        fn combatant_stun_chance(self: @ContractState, combatant_id: felt252) -> u8 {
            self.default_storage().get_combatant_stun_chance(combatant_id)
        }
    }
}
