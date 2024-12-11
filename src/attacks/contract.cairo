use dojo::world::{WorldStorage};
use blob_arena::{attacks::components::EffectInput};

#[starknet::interface]
trait IAttackActions<TContractState> {
    fn new_attack(
        ref self: TContractState,
        name: ByteArray,
        speed: u8,
        accuracy: u8,
        cooldown: u8,
        hit: Span<EffectInput>,
        miss: Span<EffectInput>,
    ) -> felt252;
}


#[dojo::contract]
mod attack_actions {
    use starknet::{ContractAddress, get_caller_address};
    use dojo::model::ModelStorage;
    use blob_arena::{
        attacks::{AttackStorage, components::{EffectInput, AttackInput}}, default_namespace, uuid
    };

    use super::IAttackActions;

    #[abi(embed_v0)]
    impl IAttackActionsImpl of IAttackActions<ContractState> {
        fn new_attack(
            ref self: ContractState,
            name: ByteArray,
            speed: u8,
            accuracy: u8,
            cooldown: u8,
            hit: Span<EffectInput>,
            miss: Span<EffectInput>,
        ) -> felt252 {
            let id = uuid();
            let mut world = self.world(default_namespace());
            world.create_attack(AttackInput { name, speed, accuracy, cooldown, hit, miss });
            id
        }
    }
}
