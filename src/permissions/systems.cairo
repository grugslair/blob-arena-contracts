use starknet::{ContractAddress, get_caller_address};

use crate::world::WorldTrait;

use super::{PermissionStorage, Permission, Role};


#[generate_trait]
impl ParentRolesImpl of ParentRoles {
    fn parent_roles(self: Role) -> Array<Role> {
        match self {
            Role::Admin => array![],
            Role::Manager => array![Role::Admin],
            Role::AmmaBlobertAdmin => array![Role::Manager, Role::Admin],
            Role::ClassicBlobertAdmin => array![Role::Manager, Role::Admin],
            Role::PvpCreator => array![Role::Manager, Role::Admin],
            Role::ArcadePaidMinter => array![Role::Manager, Role::Admin, Role::ArcadeMinter],
            Role::ArcadeFreeMinter => array![Role::Manager, Role::Admin, Role::ArcadeMinter],
            Role::ArcadeMinter => array![Role::Manager, Role::Admin],
            Role::ArcadeSetter => array![Role::Manager, Role::Admin],
            Role::AchievementSetter => array![Role::Manager, Role::Admin],
            Role::Tester => array![],
        }
    }
}


/// Trait implementation for checking various permission levels
#[generate_trait]
impl PermissionsImpl<T, +WorldTrait<T>, +Drop<T>> of Permissions<T> {
    fn has_admin_permission(self: @T, requester: ContractAddress) -> bool {
        self.get_permission(requester, Role::Admin)
    }

    fn has_role_permission(self: @T, requester: ContractAddress, role: Role) -> bool {
        self.get_permission(requester, role)
    }

    fn has_a_role_permission(self: @T, requester: ContractAddress, mut roles: Array<Role>) -> bool {
        loop {
            match roles.pop_front() {
                Option::Some(role) => {
                    if self.has_role_permission(requester, role) {
                        break true;
                    }
                },
                Option::None => { break false; },
            }
        }
    }

    fn has_parent_role_permission(self: @T, requester: ContractAddress, role: Role) -> bool {
        self.has_a_role_permission(requester, role.parent_roles())
    }

    fn has_permission(self: @T, requester: ContractAddress, role: Role) -> bool {
        self.get_permission(requester, role) || self.has_parent_role_permission(requester, role)
    }


    fn caller_has_permission(self: @T, role: Role) -> bool {
        self.has_permission(get_caller_address(), role)
    }

    fn assert_has_permission(self: @T, requester: ContractAddress, role: Role) {
        if !self.has_permission(requester, role) {
            panic!("User does not have {} permission", Into::<_, ByteArray>::into(role));
        }
    }

    fn assert_caller_has_permission(self: @T, role: Role) {
        if !self.caller_has_permission(role) {
            panic!("Caller does not have {} permission", Into::<_, ByteArray>::into(role));
        }
    }

    fn assert_caller_is_admin(self: @T) {
        self.assert_caller_has_permission(Role::Admin)
    }
}
