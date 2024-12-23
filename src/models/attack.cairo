use blob_arena::{core::Signed, components::stats::{TStats, StatTypes}};

type Stats = TStats<i8>;

#[derive(Drop, Serde, Copy, PartialEq, Introspect)]
enum Affect {
    Stats: Stats,
    Stat: Stat,
    Damage: Damage,
    Stun: u8,
    Health: i16,
}

#[derive(Drop, Serde, Copy, PartialEq, Introspect)]
struct Stat {
    stat: StatTypes,
    amount: i8,
}

#[derive(Drop, Serde, Copy, PartialEq, Introspect)]
struct Effect {
    target: Target,
    affect: Affect,
}

#[derive(Drop, Serde, Copy, PartialEq, Introspect)]
struct Damage {
    critical: u8,
    power: u8,
}

#[derive(Drop, Serde, Copy, PartialEq, Introspect)]
enum Target {
    Player,
    Opponent,
}


#[dojo::model]
#[derive(Drop, Serde)]
struct Attack {
    #[key]
    id: felt252,
    name: ByteArray,
    speed: u8,
    accuracy: u8,
    cooldown: u8,
    hit: Array<Effect>,
    miss: Array<Effect>,
}

#[dojo::model]
#[derive(Drop, Serde, Copy)]
struct AvailableAttack {
    #[key]
    combatant_id: felt252,
    #[key]
    attack_id: felt252,
    available: bool,
    last_used: u32,
}

