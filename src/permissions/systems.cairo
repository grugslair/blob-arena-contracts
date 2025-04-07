use starknet::{ContractAddress, get_caller_address};
use dojo::{world::WorldStorage, model::ModelStorage};
use super::{PermissionStorage, Permission, Role};


#[generate_trait]
impl ParentRolesImpl of ParentRoles {
    fn parent_roles(self: Role) -> Array<Role> {
        match self {
            Role::Admin => array![],
            Role::AmmaAdmin => array![Role::Admin],
            Role::BlobertAdmin => array![Role::Admin],
            Role::Creator => array![Role::Admin],
            Role::ArcadePaidMinter => array![Role::Admin, Role::ArcadeMinter],
            Role::ArcadeFreeMinter => array![Role::Admin, Role::ArcadeMinter],
            Role::ArcadeMinter => array![Role::Admin],
            Role::ArcadeSetter => array![Role::Admin],
        }
    }
}


/// Trait implementation for checking various permission levels
#[generate_trait]
impl PermissionsImpl of Permissions {
    fn has_admin_permission(self: @WorldStorage, requester: ContractAddress) -> bool {
        self.get_permission(requester, Role::Admin)
    }

    fn has_role_permission(self: @WorldStorage, requester: ContractAddress, role: Role) -> bool {
        self.get_permission(requester, role)
    }

    fn has_a_role_permission(
        self: @WorldStorage, requester: ContractAddress, mut roles: Array<Role>,
    ) -> bool {
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

    fn has_parent_role_permission(
        self: @WorldStorage, requester: ContractAddress, role: Role,
    ) -> bool {
        self.has_a_role_permission(requester, role.parent_roles())
    }

    fn has_permission(self: @WorldStorage, requester: ContractAddress, role: Role) -> bool {
        self.get_permission(requester, role) || self.has_parent_role_permission(requester, role)
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
