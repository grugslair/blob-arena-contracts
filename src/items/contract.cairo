use blob_arena::{stats::UStats, items::AttackInput};
use dojo::world::{WorldStorage};

#[starknet::interface]
trait IItemActions<ContractState> {
    fn new_item(ref self: ContractState, name: ByteArray, stats: UStats) -> felt252;
    fn new_item_with_attacks(
        ref self: ContractState, name: ByteArray, stats: UStats, attacks: Array<AttackInput>
    ) -> felt252;
}

#[dojo::contract]
mod item_actions {
    use starknet::{ContractAddress, get_caller_address, get_contract_address};

    use blob_arena::{components::{stats::Stats, item::{ItemTrait, AttackInput}}};

    use super::{IItemActions};


    #[abi(embed_v0)]
    impl IItemActionsImpl of IItemActions<ContractState> {
        fn new_item(ref self: ContractState, name: ByteArray, stats: UStats) -> felt252 {
            world.create_new_item(name, stats)
        }
        fn new_item_with_attacks(
            ref self: ContractState, name: ByteArray, stats: UStats, attacks: Array<AttackInput>
        ) -> felt252 {
            let id = world.create_new_item(name, stats);
            world.create_and_set_new_attacks(id, attacks);
            id
        }
    }
}