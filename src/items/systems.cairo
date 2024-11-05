use dojo::{world::WorldStorage, model::{ModelStorage, ModelValueStorage, ModelPtr}};
use blob_arena::{
    id_trait::IdsTrait, attacks::{components::AttackInput, AttackTrait},
    items::{Item, components::{ItemModel, HasAttack, ItemValue, HasAttackValue}}, stats::UStats,
    uuid
};
#[generate_trait]
impl ItemImpl of ItemTrait {
    fn get_item(self: @WorldStorage, id: felt252) -> Item {
        ModelStorage::<WorldStorage, ItemModel>::read_model(self, id).into()
    }
    fn get_items(self: @WorldStorage, mut ids: Span<felt252>) -> Span<Item> {
        let mut items: Array<Item> = ArrayTrait::new();

        loop {
            match ids.pop_front() {
                Option::Some(id) => { items.append(self.get_item(*id)); },
                Option::None => { break items.span(); },
            }
        }
    }
    fn create_new_item(ref self: WorldStorage, name: ByteArray, stats: UStats) -> felt252 {
        let id = uuid();
        self.write_model(@ItemModel { id, name, stats });
        id
    }
    fn set_has_attack(ref self: WorldStorage, item_id: felt252, attack_id: felt252) {
        self.write_model(@HasAttack { item_id, attack_id, has: true });
    }
    fn remove_has_attack(ref self: WorldStorage, item_id: felt252, attack_id: felt252) {
        self.erase_model_ptr(ModelPtr::<HasAttack>::Keys([item_id, attack_id].span()));
    }
    fn check_has_attack(self: @WorldStorage, item_id: felt252, attack_id: felt252) -> bool {
        ModelValueStorage::<WorldStorage, HasAttackValue>::read_value(self, (item_id, attack_id))
            .has
    }
    fn create_and_set_new_attack(
        ref self: WorldStorage, item_id: felt252, attack: @AttackInput
    ) -> felt252 {
        let id = self.create_new_attack(attack);
        self.set_has_attack(item_id, id);
        id
    }
    fn create_and_set_new_attacks(
        ref self: WorldStorage, item_id: felt252, mut attacks: Span<AttackInput>
    ) -> Span<felt252> {
        let mut attack_ids = ArrayTrait::<felt252>::new();
        loop {
            match attacks.pop_front() {
                Option::Some(attack) => {
                    attack_ids.append(self.create_and_set_new_attack(item_id, attack));
                },
                Option::None => { break; }
            }
        };
        attack_ids.span()
    }
}

