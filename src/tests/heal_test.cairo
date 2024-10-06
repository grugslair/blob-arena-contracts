// src/tests/combat_test.cairo

#[test]
#[available_gas(3000000000)]
fn test_heal_move() {
    // initial combatant state
    let initial_health: u8 = 50;
    let heal_amount: u8 = 20;
    let combatant_id: u128 = 1;
    let round: u32 = 1;

    // mock combatant state
    let mut attacker_state = CombatantState {
        id: combatant_id,
        health: initial_health,
        stun_chance: 0,
    };

    // Create a mock attack representing the "Heal" move
    let heal_attack = Attack {
        id: 1,
        name: "Heal",
        damage: 0,
        speed: 0,
        accuracy: 0,
        critical: 0,
        stun: 0,
        cooldown: 0,
        heal: heal_amount,
    };

    // Create a mock combatant stats
    let attacker_stats = CombatantStats {
        id: combatant_id,
        attack: 0,
        defense: 0,
        speed: 0,
        strength: 0,
    };

    // Mock hash state
    let hash = HashState::new();

    // Run the attack
    let (new_attacker_state, _) = CombatWorldImp::run_attack(
        IWorldDispatcher::default(),
        attacker_stats,
        attacker_state,
        CombatantState::default(),
        heal_attack,
        round,
        hash
    );

    // Verify the health has increased by the heal amount
    assert(new_attacker_state.health == initial_health + heal_amount, "Health did not increase correctly");
}