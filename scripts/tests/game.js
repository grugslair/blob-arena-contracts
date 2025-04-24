import { hash, num } from "starknet";
import { namespaceNameToHash } from "../dojo.js";

const roundResultHash = namespaceNameToHash("blob_arena-RoundResult");
const combatantStateHash = namespaceNameToHash("blob_arena-CombatantState");
export const dojoNamespaceMap = {
  [roundResultHash]: num.toHex(hash.starknetKeccak("RoundResult")),
  [combatantStateHash]: num.toHex(hash.starknetKeccak("CombatantState")),
};

export const printRoundResults = (game) => {
  const rounds = game.results;
  let combatants = {
    [game.combatant1.id]: game.combatant1,
    [game.combatant2.id]: game.combatant2,
  };
  for (let i = 0; i < rounds.length; i++) {
    const [combatant1, combatant2] = rounds[i];
    const first = combatant1.order === 0 ? combatant1 : combatant2;
    const second = combatant1.order !== 0 ? combatant1 : combatant2;
    console.log(`Round ${i + 1}: `);
    console.log(
      `Combatant ${first.index}: ${
        first.attack.name
      } ${first.result.activeVariant()}`
    );
    if (second.attack) {
      console.log(
        `Combatant ${second.index}: ${
          second.attack.name
        } ${second.result.activeVariant()}`
      );
    }
    let table = {};
    table["Health"] = {
      "Combatant A": combatant1.health,
      "Change A": combatant1.health - combatants[combatant1.id].health,
      "Combatant B": combatant2.health,
      "Change B": combatant2.health - combatants[combatant2.id].health,
    };
    const stunChange1 =
      combatant1.stun_chance - combatants[combatant1.id].stun_chance;
    const stunChange2 =
      combatant2.stun_chance - combatants[combatant2.id].stun_chance;
    table["Stun Chance"] = {
      "Combatant A": combatant1.stun_chance,
      "Change A": stunChange1 < 0 ? "R" : stunChange1,
      "Combatant B": combatant2.stun_chance,
      "Change B": stunChange2 < 0 ? "R" : stunChange2,
    };
    table["Strength"] = {
      "Combatant A": combatant1.stats.strength,
      "Change A":
        combatant1.stats.strength - combatants[combatant1.id].stats.strength,
      "Combatant B": combatant2.stats.strength,
      "Change B":
        combatant2.stats.strength - combatants[combatant2.id].stats.strength,
    };
    table["Vitality"] = {
      "Combatant A": combatant1.stats.vitality,
      "Change A":
        combatant1.stats.vitality - combatants[combatant1.id].stats.vitality,
      "Combatant B": combatant2.stats.vitality,
      "Change B":
        combatant2.stats.vitality - combatants[combatant2.id].stats.vitality,
    };
    table["Dexterity"] = {
      "Combatant A": combatant1.stats.dexterity,
      "Change A":
        combatant1.stats.dexterity - combatants[combatant1.id].stats.dexterity,
      "Combatant B": combatant2.stats.dexterity,
      "Change B":
        combatant2.stats.dexterity - combatants[combatant2.id].stats.dexterity,
    };
    table["Luck"] = {
      "Combatant A": combatant1.stats.luck,
      "Change A": combatant1.stats.luck - combatants[combatant1.id].stats.luck,
      "Combatant B": combatant2.stats.luck,
      "Change B": combatant2.stats.luck - combatants[combatant2.id].stats.luck,
    };
    combatants[combatant1.id] = combatant1;
    combatants[combatant2.id] = combatant2;
    console.table(table);
  }
};
