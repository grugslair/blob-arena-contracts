mod core;
mod models;
mod collections;
mod consts;
mod utils;
mod world;
mod components {
    mod attack;
    mod stats;
    mod combatant;
    mod item;
    mod commitment;
    mod pvp_combat;
    mod combat;
    mod utils;
    mod pvp_challenge;
}
mod systems {
    mod combat;
    // mod attack;
    mod pvp_combat;
}
mod contracts {
    mod attack;
    mod item;
    mod pvp;
    mod pvp_admin;
}

#[cfg(test)]
mod tests {
    // mod pvp_test;
    mod core_test;
    mod combat_test;
    mod utils_test;
}

