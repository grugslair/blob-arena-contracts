#[dojo::model]
#[derive(Drop, Serde, Copy)]
struct Combatants {
    #[key]
    combat_id: felt252,
    combatant_ids: (felt252, felt252),
}
