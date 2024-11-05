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

#[derive(Drop, Serde, Copy, PartialEq, Introspect)]
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
    hit: Span<EffectInput>,
    miss: Span<EffectInput>,
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

#[derive(Drop, Serde)]
struct Attack {
    id: felt252,
    speed: u8,
    accuracy: u8,
    cooldown: u8,
    hit: Span<Effect>,
    miss: Span<Effect>,
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

impl InputIntoEffectArray of Into<Span<EffectInput>, Span<Effect>> {
    fn into(mut self: Span<EffectInput>) -> Span<Effect> {
        let mut effects = array![];
        loop {
            match self.pop_front() {
                Option::Some(effect) => { effects.append((*effect).into()); },
                Option::None => { break; },
            };
        };
        effects.span()
    }
}

#[generate_trait]
impl AttackInputImpl of AttackInputTrait {
    fn to_model(self: @AttackInput, id: felt252) -> @AttackModel {
        @AttackModel {
            id,
            name: self.name.clone(),
            speed: *self.speed,
            accuracy: *self.accuracy,
            cooldown: *self.cooldown,
            hit: (*self.hit).into(),
            miss: (*self.miss).into(),
        }
    }
}

#[generate_trait]
impl AttackModelImpl of AttackModelTrait {
    fn to_attack(self: @models::Attack) -> Attack {
        Attack {
            id: *(self.id),
            speed: *(self.speed),
            accuracy: *(self.accuracy),
            cooldown: *(self.cooldown),
            hit: *self.hit,
            miss: *self.miss,
        }
    }
}


impl AttackIdImpl of IdTrait<Attack> {
    fn id(self: @Attack) -> felt252 {
        *(self.id)
    }
}

impl AttackIdsImpl = TIdsImpl<Attack>;

mod models {
    use super::Effect;
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
    #[derive(Drop, Serde)]
    struct Attack {
        #[key]
        id: felt252,
        name: ByteArray,
        speed: u8,
        accuracy: u8,
        cooldown: u8,
        hit: Span<Effect>,
        miss: Span<Effect>,
    }

    #[dojo::model]
    #[derive(Drop, Serde, Copy)]
    struct PlannedAttack {
        #[key]
        id: felt252,
        attack: felt252,
        target: felt252,
    }
}
use models::{Attack as AttackModel, AvailableAttack, AvailableAttackValue, PlannedAttack};

#[generate_trait]
impl PlannedAttacksImpl of PlannedAttacksTrait {
    fn check_all_set(self: Span<PlannedAttack>) -> bool {
        let (mut n, len) = (0, self.len());
        let mut set = true;
        while n < len {
            if (*self.at(n).attack).is_zero() {
                set = false;
                break;
            }
            n += 1;
        };
        set
    }
}
