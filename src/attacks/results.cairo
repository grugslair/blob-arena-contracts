use super::Target;

#[dojo::event]
#[derive(Drop, Serde)]
struct AttackResult {
    #[key]
    combatant_id: felt252,
    #[key]
    round: u32,
    target: felt252,
    result: AttackOutcomes,
}

#[derive(Drop, Serde, Introspect)]
enum AttackOutcomes {
    Failed,
    Stunned,
    Miss: Span<EffectResult>,
    Hit: Span<EffectResult>,
}

#[derive(Drop, Serde, Copy, PartialEq, Introspect)]
enum AffectResult {
    Success,
    Damage: DamageResult,
}

#[derive(Drop, Serde, Copy, PartialEq, Introspect)]
struct EffectResult {
    target: Target,
    affect: AffectResult,
}

#[derive(Drop, Serde, Copy, PartialEq, Introspect)]
struct DamageResult {
    damage: u8,
    critical: bool,
}
