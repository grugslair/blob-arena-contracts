use super::Target;
#[dojo::event]
#[derive(Drop, Serde)]
struct RoundResult {
    #[key]
    combat_id: felt252,
    #[key]
    round: u32,
    #[key]
    order: u32,
    combatant_id: felt252,
    attack: felt252,
    target: felt252,
    // result: AttackOutcomes,
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

#[derive(Drop, Serde, Copy, PartialEq, Introspect)]
struct EffectResult {
    target: Target,
    affect: AffectResult,
}

#[derive(Drop, Serde, Copy, PartialEq, Introspect)]
enum AffectResult {
    Success,
    Damage: DamageResult,
}

#[derive(Drop, Serde, Copy, PartialEq, IntrospectPacked)]
struct DamageResult {
    damage: u8,
    critical: bool,
}
