use crate::attack::Effect;

#[dojo::model]
#[derive(Drop, Serde, Default)]
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

