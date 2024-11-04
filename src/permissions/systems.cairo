use starknet::ContractAddress;
use dojo::world::WorldStorage;
use super::{Permissions, components::WritePermissions};
const DEV_PERMISSIONS_SELECTOR: felt252 = 'devs';
const ADMIN_PERMISSIONS_SELECTOR: felt252 = 'admin';
const SETUP_PERMISSIONS_SELECTOR: felt252 = 'setup';

#[generate_trait]
impl PermissionsImpl of HasPermissions {
    fn has_admin_permissions(self: @WorldStorage, user: ContractAddress) -> bool {
        self.get_permissions(ADMIN_PERMISSIONS_SELECTOR, user)
    }
    fn has_permissions(self: @WorldStorage, selector: felt252, user: ContractAddress) -> bool {
        self.get_permissions(selector, user) || self.has_admin_permissions(user)
    }
    fn has_dev_permissions(self: @WorldStorage, user: ContractAddress) -> bool {
        self.get_permissions(DEV_PERMISSIONS_SELECTOR, user) || self.has_admin_permissions(user)
    }
    fn has_setup_permissions(self: @WorldStorage, user: ContractAddress) -> bool {
        self.get_permissions(SETUP_PERMISSIONS_SELECTOR, user) || self.has_admin_permissions(user)
    }
}

#[generate_trait]
impl AssertPermissionsImpl of AssertPermissions {
    fn assert_admin_permissions(self: @WorldStorage, user: ContractAddress) {
        assert(self.has_admin_permissions(user), 'Not admin');
    }
    fn assert_dev_permissions(self: @WorldStorage, user: ContractAddress) {
        assert(self.has_dev_permissions(user), 'Not dev');
    }
    fn assert_setup_permissions(self: @WorldStorage, user: ContractAddress) {
        assert(self.has_setup_permissions(user), 'Not setup');
    }
}
