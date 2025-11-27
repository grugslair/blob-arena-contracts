#[starknet::contract]
mod endless_amma_contract {
    use ba_combat::Move;
    use ba_combat::systems::get_action_dispatcher_address;
    use ba_loadout::PartialAttributes;
    use ba_loadout::action::interface::maybe_create_actions_array;
    use ba_loadout::action::maybe_create_actions;
    use ba_loadout::attributes::AttributesCalcTrait;
    use ba_loadout::loadout_amma::{get_fighter_count, get_fighter_loadout};
    use ba_utils::vrf::vrf_component;
    use ba_utils::{CapInto, Randomness, RandomnessTrait};
    use beacon_library::{ToriiTable, register_table_with_schema};
    use sai_core_utils::poseidon_hash_two;
    use sai_ownable::{OwnableTrait, ownable_component};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ClassHash, ContractAddress};
    use crate::systems::{action_slots, random_selection};


    component!(path: ownable_component, storage: ownable, event: OwnableEvents);
    component!(path: vrf_component, storage: vrf, event: VrfEvents);

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: ownable_component::Storage,
        #[substorage(v0)]
        vrf: vrf_component::Storage,
        collectable_address: ContractAddress,
    }
}
