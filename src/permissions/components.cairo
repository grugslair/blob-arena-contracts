use starknet::ContractAddress;
use dojo::{world::WorldStorage, model::{ModelStorage, ModelValueStorage}};

use blob_arena::core::{BoolIntoFelt252Impl, Felt252TryIntoBoolImpl};

mod models {
    use starknet::ContractAddress;
    #[dojo::model]
    #[derive(Copy, Drop, Serde)]
    struct Permissions {
        #[key]
        resource: felt252,
        #[key]
        requester: ContractAddress,
        permissions: felt252,
    }
}

use models::{Permissions as PermissionsModel, PermissionsValue};


trait Permissions<R, P> {
    fn get_permissions(self: @WorldStorage, resource: R, requester: ContractAddress) -> P;
}

trait WritePermissions<R, P> {
    fn set_permissions(
        ref self: WorldStorage, resource: R, requester: ContractAddress, permissions: P
    );
}

impl PermissionsImpl<R, P, +Into<R, felt252>, +TryInto<felt252, P>> of Permissions<R, P> {
    fn get_permissions(self: @WorldStorage, resource: R, requester: ContractAddress) -> P {
        ModelValueStorage::<
            WorldStorage, PermissionsValue
        >::read_value(self, (resource.into(), requester))
            .try_into()
            .unwrap()
    }
}

impl WritePermissionsImpl<
    R, P, +Into<R, felt252>, +Into<P, felt252>, +Drop<P>
> of WritePermissions<R, P> {
    fn set_permissions(
        ref self: WorldStorage, resource: R, requester: ContractAddress, permissions: P
    ) {
        self
            .write_model(
                @PermissionsModel {
                    resource: resource.into(), requester, permissions: permissions.into()
                }
            )
    }
}

