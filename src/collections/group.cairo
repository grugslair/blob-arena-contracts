use starknet::ContractAddress;
use dojo::{world::WorldStorage, model::{ModelStorage, Model}};

#[derive(Drop, Copy, Serde, Introspect, PartialEq)]
enum CollectionGroup {
    None,
    FreeBlobert,
    ClassicBlobert,
    AmmaBlobert,
    TestBlobert,
}

mod model {
    use starknet::ContractAddress;
    #[dojo::model]
    #[derive(Drop, Serde)]
    struct CollectionGroup {
        #[key]
        contract_address: ContractAddress,
        group: super::CollectionGroup,
    }
}

#[generate_trait]
impl CollectionGroupStorageImpl of CollectionGroupStorage {
    fn set_collection_group(
        ref self: WorldStorage, contract_address: ContractAddress, group: CollectionGroup,
    ) {
        self.write_model(@model::CollectionGroup { contract_address, group });
    }

    fn get_collection_group(
        self: @WorldStorage, contract_address: ContractAddress,
    ) -> CollectionGroup {
        self
            .read_member(
                Model::<model::CollectionGroup>::ptr_from_keys(contract_address),
                selector!("group"),
            )
    }
}
