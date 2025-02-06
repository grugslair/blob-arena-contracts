use super::Target;
#[dojo::event]
#[derive(Drop, Serde)]
struct RoundResult {
    #[key]
    combat_id: felt252,
    #[key]
    round: u32,
    attacks: Array<AttackResult>,
}

#[derive(Drop, Serde, Introspect)]
struct AttackResult {
    combatant_id: felt252,
    attack: felt252,
    target: felt252,
    result: AttackOutcomes,
}

#[derive(Drop, Serde, Introspect)]
enum AttackOutcomes {
    Failed,
    Stunned,
    Miss: Array<EffectResult>,
    Hit: Array<EffectResult>,
}

#[derive(Drop, Serde, PartialEq, Introspect)]
struct EffectResult {
    target: Target,
    affect: AffectResult,
}

#[derive(Drop, Serde, PartialEq, Introspect)]
enum AffectResult {
    Success,
    Damage: DamageResult,
}

#[derive(Drop, Serde, PartialEq, IntrospectPacked)]
struct DamageResult {
    damage: u8,
    critical: bool,
}
