use blob_arena::{
    core::Signed, stats::{IStats, StatTypes, SignedStats}, id_trait::{IdTrait, TIdsImpl},
};

const ATTACK_TAG_GROUP: felt252 = 'attacks';

/// Setup models

/// A struct representing an attack in the game.
///
/// # Fields
/// * `id` - Unique identifier for the attack
/// * `speed` - The speed of the attack (0-100)
/// * `accuracy` - The accuracy of the attack (0-100)
/// * `cooldown` - The cooldown period of the attack in rounds
/// * `hit` - Array of effects that occur when the attack hits
/// * `miss` - Array of effects that occur when the attack misses
#[dojo::model]
#[derive(Drop, Serde, Default)]
struct Attack {
    #[key]
    id: felt252,
    speed: u8,
    accuracy: u8,
    cooldown: u8,
    hit: Array<Effect>,
    miss: Array<Effect>,
    requirements: Array<AttackRequirement>,
}

#[dojo::event]
#[derive(Drop, Serde)]
struct AttackName {
    #[key]
    id: felt252,
    name: ByteArray,
}

/// Game models

/// A component that tracks when a specific attack was last used by a combatant.
/// The attack_id represents the unique identifier for an attack ability.
/// The last_used timestamp helps enforce cooldown periods between attack uses.
///
/// # Arguments
///
/// * `combatant_id` - The unique identifier of the combatant
/// * `attack_id` - The unique identifier of the attack
/// * `last_used` - Timestamp of when the attack was last used
#[dojo::model]
#[derive(Drop, Serde)]
struct AttackLastUsed {
    #[key]
    combatant_id: felt252,
    #[key]
    attack_id: felt252,
    last_used: u32,
}


/// Represents a planned attack in the combat system
/// * `combatant_id` - The unique identifier of the attacking combatant
/// * `attack_id` - The identifier of the attack type being used
/// * `target` - The identifier of the target being attacked
/// * `salt` - A random value used to prevent attack prediction and used for the random seed
#[dojo::model]
#[derive(Drop, Serde, Copy)]
struct PlannedAttack {
    #[key]
    combatant_id: felt252,
    attack_id: felt252,
    target: felt252,
    salt: felt252,
}

/// A component representing an attack or input of attack in the game.
///
/// # Attributes
///
/// * `id` - A unique identifier for the attack.
/// * `speed` - The speed of the attack, represented as a value between 0 and 255.
/// * `accuracy` - The likelihood of the attack hitting its target, represented as a value between 0
/// and 100.
/// * `cooldown` - The number of turns required before the attack can be used again.
/// * `hit` - An array of effects that are applied when the attack successfully hits.
/// * `miss` - An array of effects that are applied when the attack misses.
/// * `name` - The name of the attack. (For off chain use)

#[derive(Drop, Serde)]
struct AttackInput {
    name: ByteArray,
    speed: u8,
    accuracy: u8,
    cooldown: u8,
    hit: Array<EffectInput>,
    miss: Array<EffectInput>,
    requirements: Array<AttackRequirement>,
}

/// Represents an effect that can be applied during the game.
///
/// # Arguments
/// * `target` - Specifies who receives the effect (Player or Opponent)
/// * `affect` - The type of effect to be applied

#[derive(Drop, Serde, PartialEq, Introspect)]
struct Effect {
    target: Target,
    affect: Affect,
}

#[derive(Copy, Drop, Serde, PartialEq)]
struct EffectInput {
    target: Target,
    affect: AffectInput,
}


#[derive(Drop, Serde, Copy, PartialEq, Introspect)]
enum Target {
    Player,
    Opponent,
}

#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
enum AttackRequirement {
    MinExperience: u128,
    MaxExperience: u128,
}

/// Represents different types of effects that can be applied in the game
/// * `Stats` - Multiple stat modifications applied at once using SignedStats
/// * `Stat` - A single stat modification using StatInput
/// * `Damage` - Direct damage effect
/// * `Stun` - Stun chance increase of target on next attack in percentage
/// * `Health` - Health modification (can be positive for healing or negative for damage)

#[derive(Copy, Drop, Serde, PartialEq)]
enum AffectInput {
    Stats: SignedStats,
    Stat: StatInput,
    Damage: Damage,
    Stun: u8,
    Health: Signed<u8>,
}

#[derive(Drop, Serde, Copy, PartialEq, Introspect)]
enum Affect {
    Stats: IStats,
    Stat: Stat,
    Damage: Damage,
    Stun: u8,
    Health: i16,
}


/// Represents a modifier to a stat in the game.
/// * `stat` - The type of statistic (Strength, Vitality, Dexterity, Luck)
/// * `amount` - The numerical value of the stat, ranging from -100 to +100

#[derive(Drop, Serde, Copy, PartialEq, Introspect)]
struct Stat {
    stat: StatTypes,
    amount: i8,
}

#[derive(Drop, Serde, Copy, PartialEq)]
struct StatInput {
    stat: StatTypes,
    amount: Signed<u8>,
}


/// Represents damage attributes of an attack.
/// * `critical` - Critical hit chance value between 0-100
/// * `power` - Attack power value between 0-100

#[derive(Drop, Serde, Copy, PartialEq, Introspect)]
struct Damage {
    critical: u8,
    power: u8,
}

/// A component that tracks whether a specific attack is available for a combatant.
/// The attack_id represents the unique identifier for an attack ability.
/// If available is true, the attack can be used by the combatant.
///
/// # Arguments
///
/// * `combatant_id` - The unique identifier of the combatant
/// * `attack_id` - The unique identifier of the attack
/// * `available` - Boolean indicating if the attack is available for use

#[dojo::model]
#[derive(Drop, Serde)]
struct AttackAvailable {
    #[key]
    combatant_id: felt252,
    #[key]
    attack_id: felt252,
    available: bool,
}


#[derive(Drop, Serde, Introspect)]
struct AttackExists {
    hit: u32,
    miss: u32,
}


impl InputIntoAffect of Into<AffectInput, Affect> {
    fn into(self: AffectInput) -> Affect {
        match self {
            AffectInput::Stats(stats) => Affect::Stats(stats.into()),
            AffectInput::Stat(stat) => Affect::Stat(
                Stat { stat: stat.stat, amount: stat.amount.into() },
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
    fn to_attack_and_name(self: AttackInput, id: felt252) -> (Attack, ByteArray) {
        (
            Attack {
                id,
                speed: self.speed,
                accuracy: self.accuracy,
                cooldown: self.cooldown,
                hit: self.hit.into(),
                miss: self.miss.into(),
                requirements: self.requirements,
            },
            self.name,
        )
    }
}


impl AttackIdImpl of IdTrait<Attack> {
    fn id(self: @Attack) -> felt252 {
        *(self.id)
    }
}

impl AttackIdsImpl = TIdsImpl<Attack>;

