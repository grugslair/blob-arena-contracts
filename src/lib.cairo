mod core;
mod consts;
mod utils;
mod id_trait;
mod items {
    mod components;
    mod systems;
    use components::Item;
    use systems::ItemTrait;
}
mod attacks {
    mod components;
    mod systems;
    mod contract;
    use components::Attack;
    use systems::AttackTrait;
}
mod stats;
mod combatant {
    mod components;
    mod systems;
}
// mod models;
// mod collections;

// mod world;
mod commitment;
// mod components {
//     mod attack;
//     mod stats;
//     mod combatant;
//     mod item;
//     mod pvp_combat;
//     mod combat;
//     mod utils;
//     mod pvp_challenge;
// }
// mod systems {
//     mod combat;
//     // mod attack;
//     mod pvp_combat;
// }
// mod contracts {
//     mod attack;
//     mod item;
//     mod pvp;
//     mod pvp_admin;
// }

// #[cfg(test)]
// mod tests {
//     // mod pvp_test;
//     mod core_test;
//     mod combat_test;
//     mod utils_test;
// }


