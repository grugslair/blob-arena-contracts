use starknet::ContractAddress;
use dojo::{world::WorldStorage, model::{ModelStorage, Model}};
use blob_arena::world::WorldTrait;

#[derive(Drop, Copy, Serde, PartialEq, Introspect)]
enum Role {
    Admin,
    AmmaAdmin,
    BlobertAdmin,
    Creator,
    ArcadePaidMinter,
    ArcadeFreeMinter,
    ArcadeMinter,
    ArcadeSetter,
}

impl RoleIntoByteArrayImpl of Into<Role, ByteArray> {
    fn into(self: Role) -> ByteArray {
        match self {
            Role::Admin => "admin",
            Role::AmmaAdmin => "amma admin",
            Role::BlobertAdmin => "Blobert admin",
            Role::Creator => "creator",
            Role::ArcadePaidMinter => "paid minter",
            Role::ArcadeFreeMinter => "free minter",
            Role::ArcadeMinter => "minter",
            Role::ArcadeSetter => "arcade setter",
        }
    }
}


#[dojo::model]
#[derive(Drop, Serde)]
struct Permission {
    #[key]
    requester: ContractAddress,
    #[key]
    role: Role,
    has: bool,
}

trait PermissionStorage {
    fn get_permissions_storage(self: @WorldStorage) -> WorldStorage;
    fn get_permission(self: @WorldStorage, requester: ContractAddress, role: Role) -> bool;
    fn set_permission(ref self: WorldStorage, requester: ContractAddress, role: Role, has: bool);
    fn set_permissions(ref self: WorldStorage, permissions: Array<Permission>);
}

/// Implementation of the Permissions trait
///
/// Requires that P can be converted from felt252
impl PermissionImpl of PermissionStorage {
    fn get_permissions_storage(self: @WorldStorage) -> WorldStorage {
        self.storage(bytearray_hash!("ba_permissions"))
    }

    fn get_permission(self: @WorldStorage, requester: ContractAddress, role: Role) -> bool {
        self
            .get_permissions_storage()
            .read_member(Model::<Permission>::ptr_from_keys((requester, role)), selector!("has"))
    }

    fn set_permission(ref self: WorldStorage, requester: ContractAddress, role: Role, has: bool) {
        let mut storage = self.get_permissions_storage();
        storage.write_model(@Permission { requester, role, has })
    }

    fn set_permissions(ref self: WorldStorage, permissions: Array<Permission>) {
        let mut array = ArrayTrait::<@Permission>::new();
        for permission in permissions {
            array.append(@permission);
        };
        let mut storage = self.get_permissions_storage();
        storage.write_models(array.span());
    }
}
