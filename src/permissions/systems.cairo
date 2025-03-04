use starknet::{ContractAddress, get_caller_address};
use dojo::{world::WorldStorage, model::ModelStorage};
use super::{PermissionStorage, Permission, Role};


/// Trait implementation for checking various permission levels
#[generate_trait]
impl PermissionsImpl of Permissions {
    fn has_admin_permission(self: @WorldStorage, requester: ContractAddress) -> bool {
        self.get_permission(requester, Role::Admin)
    }

    fn has_role_permission(self: @WorldStorage, requester: ContractAddress, role: Role) -> bool {
        self.get_permission(requester, role)
    }

    fn has_permission(self: @WorldStorage, requester: ContractAddress, role: Role) -> bool {
        self.get_permission(requester, role) || self.has_admin_permission(requester)
    }

    fn caller_has_permission(self: @WorldStorage, role: Role) -> bool {
        self.has_permission(get_caller_address(), role)
    }

    fn assert_has_permission(self: @WorldStorage, requester: ContractAddress, role: Role) {
        if !self.has_permission(requester, role) {
            panic!("User does not have {} permission", Into::<_, ByteArray>::into(role));
        }
    }

    fn assert_caller_has_permission(self: @WorldStorage, role: Role) {
        if !self.caller_has_permission(role) {
            panic!("Caller does not have {} permission", Into::<_, ByteArray>::into(role));
        }
    }

    fn assert_caller_is_admin(self: @WorldStorage) {
        self.assert_caller_has_permission(Role::Admin)
    }
}
