use starknet::ContractAddress;
use crate::permissions::Role;
use crate::achievements::TrophyCreationInput;


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

#[dojo::contract]
mod admin_actions {
    use dojo::world::WorldStorage;
    use starknet::{ContractAddress, get_tx_info};
    use crate::world::{WorldTrait, get_world_address};
    use crate::permissions::{Role, Permissions, Permission, PermissionStorage};
    use crate::achievements::{Achievements, TrophyCreationInput};
    use super::{IPermissions, IAchievements};

    fn dojo_init(ref self: ContractState) {
        let mut world = self.default_storage();

        let admin = get_tx_info().unbox().account_contract_address;
        world.set_permission(admin, Role::Admin, true);
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
}
