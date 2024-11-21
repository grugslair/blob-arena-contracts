use super::Target;

#[dojo::event]
#[derive(Drop, Serde)]
struct AttackResult {
    #[key]
    combatant_id: felt252,
    #[key]
    round: u32,
    attack: felt252,
    target: felt252,
    result: AttackOutcomes,
}

mod events {
    use super::Target;
    #[dojo::event]
    #[derive(Drop, Serde, Copy, PartialEq)]
    struct DamageResult {
        #[key]
        combatant_id: felt252,
        #[key]
        round: u32,
        #[key]
        move: u32,
        target: Target,
        damage: u8,
        critical: bool,
    }
}


#[derive(Drop, Serde, Introspect)]
enum AttackOutcomes {
    Failed,
    Stunned,
    Miss,
    Hit,
}

#[derive(Drop, Serde, Copy, PartialEq)]
enum AffectResult {
    Success,
    Damage: DamageResult,
}

#[derive(Drop, Serde, Copy, PartialEq)]
struct EffectResult {
    n: u32,
    target: Target,
    affect: AffectResult,
}

#[derive(Drop, Serde, Copy, PartialEq)]
struct DamageResult {
    damage: u8,
    critical: bool,
}
