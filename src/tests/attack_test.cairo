use blob_arena::attacks::{AvailableAttackTrait, components::models::AvailableAttack};

fn assert_usable(attack: AvailableAttack, cooldown: u8, round: u32) {
    assert!(
        attack.check_attack_useable(cooldown, round),
        "last_used: {}, cooldown: {}, round: {}",
        attack.last_used,
        cooldown,
        round
    );
}

fn assert_unusable(attack: AvailableAttack, cooldown: u8, round: u32) {
    assert!(
        attack.check_attack_useable(cooldown, round) == false,
        "last_used: {}, cooldown: {}, round: {}",
        attack.last_used,
        cooldown,
        round
    );
}
#[test]
fn test_attack_useable() {
    let mut attack = AvailableAttack {
        combatant_id: 0, attack_id: 0, available: true, last_used: 0,
    };
    // attack          cooldown        round
    // next round after last_used
    assert_usable(attack, 0, attack.last_used + 1);
    assert_usable(attack, 1, attack.last_used + 1);
    assert_usable(attack, 2, attack.last_used + 1);

    // two rounds after last_used
    assert_usable(attack, 0, attack.last_used + 2);
    assert_usable(attack, 1, attack.last_used + 2);
    assert_usable(attack, 2, attack.last_used + 2);

    // three rounds after last_used
    assert_usable(attack, 0, attack.last_used + 3);
    assert_usable(attack, 1, attack.last_used + 3);
    assert_usable(attack, 2, attack.last_used + 3);
    attack.last_used = 1;
    // next round after last_used
    assert_usable(attack, 0, attack.last_used + 1);
    assert_unusable(attack, 1, attack.last_used + 1);
    assert_unusable(attack, 2, attack.last_used + 1);

    // two rounds after last_used
    assert_usable(attack, 0, attack.last_used + 2);
    assert_usable(attack, 1, attack.last_used + 2);
    assert_unusable(attack, 2, attack.last_used + 2);

    // three rounds after last_used
    assert_usable(attack, 0, attack.last_used + 3);
    assert_usable(attack, 1, attack.last_used + 3);
    assert_usable(attack, 2, attack.last_used + 3);
    attack.available = false;

    // attack not available
    assert_unusable(attack, 0, attack.last_used + 10);
}

