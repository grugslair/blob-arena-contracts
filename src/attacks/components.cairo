use blob_arena::{
    core::Signed, stats::{IStats, StatTypes, SignedStats}, id_trait::{IdTrait, TIdsImpl,}
};

#[derive(Drop, Serde, Copy, PartialEq, IntrospectPacked)]
struct Stat {
    stat: StatTypes,
    amount: i8,
}

#[derive(Drop, Serde, Copy, PartialEq, IntrospectPacked)]
enum Target {
    Player,
    Opponent,
}

#[derive(Drop, Serde, PartialEq, Introspect)]
struct Effect {
    target: Target,
    affect: Affect,
}

#[derive(Drop, Serde, Copy, PartialEq)]
struct StatInput {
    stat: StatTypes,
    amount: Signed<u8>,
}

#[derive(Copy, Drop, Serde, PartialEq)]
struct EffectInput {
    target: Target,
    affect: AffectInput,
}

#[derive(Copy, Drop, Serde, PartialEq)]
enum AffectInput {
    Stats: SignedStats,
    Stat: StatInput,
    Damage: Damage,
    Stun: u8,
    Health: Signed<u8>,
}

#[derive(Drop, Serde)]
struct AttackInput {
    name: ByteArray,
    speed: u8,
    accuracy: u8,
    cooldown: u8,
    hit: Array<EffectInput>,
    miss: Array<EffectInput>,
}

#[derive(Drop, Serde, Copy, PartialEq, Introspect)]
enum Affect {
    Stats: IStats,
    Stat: Stat,
    Damage: Damage,
    Stun: u8,
    Health: i16,
}

#[derive(Drop, Serde, Copy, PartialEq, IntrospectPacked)]
struct Damage {
    critical: u8,
    power: u8,
}

#[dojo::event]
#[derive(Drop, Serde)]
struct AttackName {
    #[key]
    id: felt252,
    name: ByteArray,
}

#[dojo::model]
#[derive(Drop, Serde)]
struct Attack {
    #[key]
    id: felt252,
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


#[dojo::model]
#[derive(Drop, Serde, Copy)]
struct PlannedAttack {
    #[key]
    combatant_id: felt252,
    attack_id: felt252,
    target: felt252,
}


impl InputIntoAffect of Into<AffectInput, Affect> {
    fn into(self: AffectInput) -> Affect {
        match self {
            AffectInput::Stats(stats) => Affect::Stats(stats.into()),
            AffectInput::Stat(stat) => Affect::Stat(
                Stat { stat: stat.stat, amount: stat.amount.into() }
            ),
            AffectInput::Damage(damage) => Affect::Damage(damage),
            AffectInput::Stun(stun) => Affect::Stun(stun),
            AffectInput::Health(health) => Affect::Health(health.into()),
        }
    }
}

impl InputIntoEffect of Into<EffectInput, Effect> {
    fn into(self: EffectInput) -> Effect {
        Effect { target: self.target, affect: self.affect.into() }
    }
}

impl InputIntoEffectArray of Into<Array<EffectInput>, Array<Effect>> {
    fn into(mut self: Array<EffectInput>) -> Array<Effect> {
        let mut effects = array![];
        loop {
            match self.pop_front() {
                Option::Some(effect) => { effects.append(effect.into()); },
                Option::None => { break; },
            };
        };
        effects
    }
}

#[generate_trait]
impl AttackInputImpl of AttackInputTrait {
    fn to_attack_and_name(self: AttackInput, id: felt252) -> (Attack, AttackName) {
        (
            Attack {
                id,
                speed: self.speed,
                accuracy: self.accuracy,
                cooldown: self.cooldown,
                hit: self.hit.into(),
                miss: self.miss.into(),
            },
            AttackName { id, name: self.name }
        )
    }
}

#[generate_trait]
impl AvailableAttackImpl of AvailableAttackTrait {
    fn check_attack_useable(self: @AvailableAttack, cooldown: u8, round: u32) -> bool {
        *self.available
            && ((*self.last_used).is_zero() || *self.last_used + cooldown.into() < round)
    }
}


impl AttackIdImpl of IdTrait<Attack> {
    fn id(self: @Attack) -> felt252 {
        *(self.id)
    }
}

impl AttackIdsImpl = TIdsImpl<Attack>;

