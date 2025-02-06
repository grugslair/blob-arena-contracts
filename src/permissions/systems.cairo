use starknet::{ContractAddress, get_caller_address};
use dojo::{world::WorldStorage, model::ModelStorage};
use super::{PermissionStorage, Permission};

/// Permission selector constants for different access levels
const ADMIN_PERMISSION_SELECTOR: felt252 = 'admin';
const SETUP_PERMISSION_SELECTOR: felt252 = 'creator';

/// Trait implementation for checking various permission levels
#[generate_trait]
impl GamePermissionsImpl of GamePermissions {
    /// Checks if a user has admin permissions
    /// # Arguments
    /// * `self` - The world storage reference
    /// * `user` - The contract address to check permissions for
    /// # Returns
    /// * `bool` - True if user has admin permissions, false otherwise
    fn has_admin_permission(self: @WorldStorage, user: ContractAddress) -> bool {
        self.get_permission(ADMIN_PERMISSION_SELECTOR, user)
    }

    /// Checks if a user has creator permissions
    /// # Arguments
    /// * `self` - The world storage reference
    /// * `user` - The contract address to check permissions for
    /// # Returns
    /// * `bool` - True if user has creator permissions or admin permissions
    fn has_creator_permission(self: @WorldStorage, user: ContractAddress) -> bool {
        self.get_permission(SETUP_PERMISSION_SELECTOR, user) || self.has_admin_permission(user)
    }

    /// Asserts that a user has admin permissions
    /// # Arguments
    /// * `self` - The world storage reference
    /// * `user` - The contract address to check permissions for
    /// # Panics
    /// Panics if the user does not have admin permissions
    fn assert_admin_permission(self: @WorldStorage, user: ContractAddress) {
        assert(self.has_admin_permission(user), 'Not admin');
    }

    fn assert_caller_is_admin(self: @WorldStorage) -> ContractAddress {
        let caller = get_caller_address();
        self.assert_admin_permission(caller);
        caller
    }

    /// Asserts that a user has creator permissions
    /// # Arguments
    /// * `self` - The world storage reference
    /// * `user` - The contract address to check permissions for
    /// # Panics
    /// Panics if the user does not have creator permissions
    fn assert_creator_permission(self: @WorldStorage, user: ContractAddress) {
        assert(self.has_creator_permission(user), 'Not creator');
    }

    fn assert_caller_is_creator(self: @WorldStorage) -> ContractAddress {
        let caller = get_caller_address();
        self.assert_creator_permission(caller);
        caller
    }

    fn set_admin_permission(ref self: WorldStorage, user: ContractAddress, has: bool) {
        self.set_permission(ADMIN_PERMISSION_SELECTOR, user, has);
    }

    fn set_creator_permission(ref self: WorldStorage, user: ContractAddress, has: bool) {
        self.set_permission(SETUP_PERMISSION_SELECTOR, user, has);
    }

    fn set_admins_permission(ref self: WorldStorage, users: Array<ContractAddress>, has: bool) {
        let mut permissions = ArrayTrait::<Permission<bool>>::new();
        for user in users {
            permissions
                .append(
                    Permission {
                        resource: ADMIN_PERMISSION_SELECTOR, requester: user, permission: has,
                    },
                );
        };
        self.set_permissions(permissions);
    }

    fn set_creators_permission(ref self: WorldStorage, users: Array<ContractAddress>, has: bool) {
        let mut permissions = ArrayTrait::<Permission<bool>>::new();
        for user in users {
            permissions
                .append(
                    Permission {
                        resource: SETUP_PERMISSION_SELECTOR, requester: user, permission: has,
                    },
                );
        };
        self.set_permissions(permissions);
    }
}
