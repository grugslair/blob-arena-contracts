import { hash, num } from "starknet";
import { DojoParser, namespaceNameToHash } from "../dojo.js";

const roundResultHash = namespaceNameToHash("blob_arena-RoundResult");
const combatantStateHash = namespaceNameToHash("blob_arena-CombatantState");
const roundResultPath = "blob_arena::attacks::results::RoundResult";
const combatantStatePath = "blob_arena::combatants::components::CombatantState";

export const dojoNamespaceMap = {
  [roundResultHash]: num.toHex(hash.starknetKeccak("RoundResult")),
  [combatantStateHash]: num.toHex(hash.starknetKeccak("CombatantState")),
};

export const printRoundResults = (game) => {
  let combatants = {
    [game.combatants[0].id]: game.combatants[0],
    [game.combatants[1].id]: game.combatants[1],
  };
  let stateA = game.combatants[0];
  let stateB = game.combatants[1];
  const allAttacks = Object.fromEntries(
    stateA.attacks.concat(stateB.attacks).map((a) => [a.id, a])
  );

  const combatantAId = stateA.id;
  const combatantBId = stateB.id;

  const combatantNames = {
    [combatantAId]: "Combatant A",
    [combatantBId]: "Combatant B",
  };
  const combatantAName = combatantNames[combatantAId];
  const combatantBName = combatantNames[combatantBId];
  for (const [n, { attacks, states }] of game.rounds.entries()) {
    console.log(`Round ${n + 1}: `);
    const [attackResult1, attackResult2] = attacks;
    const combatantA = states[combatantAId];
    const combatantB = states[combatantBId];
    console.log(
      `${combatantNames[attackResult1.combatant_id]}: ${
        allAttacks[attackResult1.attack].name
      } ${attackResult1.result.activeVariant()}`
    );
    if (attackResult2) {
      console.log(
        `${combatantNames[attackResult2.combatant_id]}: ${
          allAttacks[attackResult2.attack].name
        } ${attackResult2.result.activeVariant()}`
      );
    }

    let table = {};
    table["Health"] = {
      [combatantAName]: combatantA.health,
      "Change A": combatantA.health - stateA.health,
      [combatantBName]: combatantB.health,
      "Change B": combatantB.health - stateB.health,
    };
    const stunChange1 = combatantA.stun_chance - stateA.stun_chance;
    const stunChange2 = combatantB.stun_chance - stateB.stun_chance;
    table["Stun Chance"] = {
      [combatantAName]: combatantA.stun_chance,
      "Change A": stunChange1 < 0 ? "R" : stunChange1,
      [combatantBName]: combatantB.stun_chance,
      "Change B": stunChange2 < 0 ? "R" : stunChange2,
    };
    table["Strength"] = {
      [combatantAName]: combatantA.stats.strength,
      "Change A": combatantA.stats.strength - stateA.stats.strength,
      [combatantBName]: combatantB.stats.strength,
      "Change B": combatantB.stats.strength - stateB.stats.strength,
    };
    table["Vitality"] = {
      [combatantAName]: combatantA.stats.vitality,
      "Change A": combatantA.stats.vitality - stateA.stats.vitality,
      [combatantBName]: combatantB.stats.vitality,
      "Change B": combatantB.stats.vitality - stateB.stats.vitality,
    };
    table["Dexterity"] = {
      [combatantAName]: combatantA.stats.dexterity,
      "Change A": combatantA.stats.dexterity - stateA.stats.dexterity,
      [combatantBName]: combatantB.stats.dexterity,
      "Change B": combatantB.stats.dexterity - stateB.stats.dexterity,
    };
    table["Luck"] = {
      [combatantAName]: combatantA.stats.luck,
      "Change A": combatantA.stats.luck - stateA.stats.luck,
      [combatantBName]: combatantB.stats.luck,
      "Change B": combatantB.stats.luck - stateB.stats.luck,
    };
    stateA = combatantA;
    stateB = combatantB;
    console.table(table);
  }
};

export const getRoundResults = async (
  provider,
  dojoParser,
  transaction_hash
) => {
  const { events: rawEvents } = await provider.waitForTransaction(
    transaction_hash
  );
  const events = dojoParser.parseEvents(rawEvents);
  const combatants = Object.fromEntries(
    events
      .filter((e) => combatantStatePath in e)
      .map((e) => {
        const { id, health, stun_chance, stats } = e[combatantStatePath];
        return [id, { id, health, stun_chance, stats }];
      })
  );
  let games = [];
  for (const event of events.filter((e) => roundResultPath in e)) {
    const { combat_id, attacks } = event[roundResultPath];
    const { combatant_id, target } = attacks[0];
    games.push({
      combat_id,
      attacks,
      states: {
        [combatant_id]: combatants[combatant_id],
        [target]: combatants[target],
      },
    });
  }
  return games;
};

export const printAttackResults = (game) => {
  let stateA = game.combatants[0];
  let stateB = game.combatants[1];
  const allAttacks = Object.fromEntries(
    stateA.attacks.concat(stateB.attacks).map((a) => [a.id, a])
  );

  const combatantAId = stateA.id;
  const combatantBId = stateB.id;

  const combatantNames = {
    [combatantAId]: "Combatant A",
    [combatantBId]: "Combatant B",
  };
  const combatantAName = combatantNames[combatantAId];
  const combatantBName = combatantNames[combatantBId];
  for (const [n, { attacks, states }] of game.rounds.entries()) {
    console.log(`Round ${n + 1}: `);
    const [attackResult1, attackResult2] = attacks;
    const combatantA = states[combatantAId];
    const combatantB = states[combatantBId];
    console.log(
      `${combatantNames[attackResult1.combatant_id]}: ${
        allAttacks[attackResult1.attack].name
      } ${attackResult1.result.activeVariant()}`
    );
    if (attackResult2) {
      console.log(
        `${combatantNames[attackResult2.combatant_id]}: ${
          allAttacks[attackResult2.attack].name
        } ${attackResult2.result.activeVariant()}`
      );
    }
  }
};
