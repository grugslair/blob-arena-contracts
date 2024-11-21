use blob_arena::{stats::UStats, attacks::components::AttackInput};
use dojo::world::{WorldStorage};

#[starknet::interface]
trait IItemActions<ContractState> {
    fn new_item(ref self: ContractState, name: ByteArray, stats: UStats) -> felt252;
    fn new_item_with_attacks(
        ref self: ContractState, name: ByteArray, stats: UStats, attacks: Span<AttackInput>
    ) -> felt252;
}

#[dojo::contract]
mod item_actions {
    use starknet::{ContractAddress, get_caller_address, get_contract_address};

    use blob_arena::{
        stats::UStats, items::ItemTrait, attacks::components::AttackInput, default_namespace
    };

    use super::{IItemActions};


    #[abi(embed_v0)]
    impl IItemActionsImpl of IItemActions<ContractState> {
        fn new_item(ref self: ContractState, name: ByteArray, stats: UStats) -> felt252 {
            let mut world = self.world(default_namespace());
            world.create_new_item(name, stats)
        }
        fn new_item_with_attacks(
            ref self: ContractState, name: ByteArray, stats: UStats, attacks: Span<AttackInput>
        ) -> felt252 {
            let mut world = self.world(default_namespace());
            let id = world.create_new_item(name, stats);
            world.create_and_set_new_attacks(id, attacks);
            id
        }
    }
}
