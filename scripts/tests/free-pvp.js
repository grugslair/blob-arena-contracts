import {
  dataToByteArray,
  loadAccountManifestFromCmdArgs,
  newAccounts,
} from "../stark-utils.js";
import { randomIndexes } from "../utils.js";
import {
  freeBlobertContractTag,
  lobbyContractTag,
  pvpContractTag,
  adminContractTag,
} from "../contract-defs.js";
import { makeLobby } from "./lobby.js";
import { runPvpBattles, runRounds } from "./pvp.js";
import { bigIntToHex } from "web3-eth-accounts";
import { mintFreeTokenWithAttacks } from "./classic-blobert.js";
import { getAttacks } from "./attacks.js";

const accountClassHash =
  "0x07489e371db016fcd31b78e49ccd201b93f4eab60af28b862390e800ec9096e2";

const main = async () => {
  const account_manifest = await loadAccountManifestFromCmdArgs();
  const account = account_manifest.account;
  const freeContract = await account_manifest.getContract(
    freeBlobertContractTag
  );
  const lobbyContract = await account_manifest.getContract(lobbyContractTag);
  const gameContract = await account_manifest.getContract(pvpContractTag);
  const adminContract = await account_manifest.getContract(adminContractTag);
  const worldContract = await account_manifest.getWorldContract();

  console.log("Deploying new accounts");
  const [account1, account2] = await newAccounts(account, accountClassHash, 2);
  console.log("Accounts deployed");

  const player1Tokens = [];
  const player2Tokens = [];
  let allAttackIds = new Set();
  for (let i = 0; i < 4; i++) {
    player1Tokens.push(
      await mintFreeTokenWithAttacks(account, account1, freeContract)
    );

    player2Tokens.push(
      await mintFreeTokenWithAttacks(account, account2, freeContract)
    );
    player1Tokens[i].attacks.forEach(allAttackIds.add, allAttackIds);
    player2Tokens[i].attacks.forEach(allAttackIds.add, allAttackIds);
  }
  const attacks = await getAttacks(
    worldContract,
    adminContract,
    Array.from(allAttackIds).map(bigIntToHex)
  );
  let games = [];
  let combatants = {};
  for (let i = 0; i < player1Tokens.length; i++) {
    const token1 = player1Tokens[i];
    for (let j = 0; j < player2Tokens.length; j++) {
      const token2 = player2Tokens[j];

      const attackIndexes1 = randomIndexes(token1.attack_slots.length, 4);
      const attackIndexes2 = randomIndexes(token2.attack_slots.length, 4);
      const attacks1 = attackIndexes1.map((index) => token1.attacks[index]);
      const attacks2 = attackIndexes2.map((index) => token2.attacks[index]);
      const attackSlots1 = attackIndexes1.map(
        (index) => token1.attack_slots[index]
      );
      const attackSlots2 = attackIndexes2.map(
        (index) => token2.attack_slots[index]
      );
      const [gameId, combatantId1, combatantId2] = await makeLobby(
        account,
        account1,
        account2,
        lobbyContract,
        gameContract,
        freeContract.address,
        token1.token_id,
        attackSlots1,
        token2.token_id,
        attackSlots2
      );

      const combatant1 = {
        id: combatantId1,
        token_id: token1.token_id,
        attacks: Object.fromEntries(attacks1.map((a) => [a, 0])),
        attack_slots: attackSlots1,
        stats: await gameContract.combatant_stats(combatantId1),
        health: await gameContract.combatant_health(combatantId1),
        stun_chance: BigInt(0),
      };
      const combatant2 = {
        id: combatantId2,
        token_id: token2.token_id,
        attacks: Object.fromEntries(attacks2.map((a) => [a, 0])),
        attack_slots: attackSlots2,
        stats: await gameContract.combatant_stats(combatantId2),
        health: await gameContract.combatant_health(combatantId2),
        stun_chance: BigInt(0),
      };
      combatants[combatantId1] = combatant1;
      combatants[combatantId2] = combatant2;
      games.push({
        combat_id: BigInt(gameId),
        combatant1,
        combatant2,
        round: 1,
        winner: null,
        rounds: [],
      });
    }
  }
  const results = await runPvpBattles(
    worldContract,
    account,
    account1,
    account2,
    gameContract,
    games,
    attacks
  );
  for (const [combatId, rounds] of Object.entries(results)) {
    console.log(combatId);

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
        "Combatant 1": combatant1.health,
        "Change 1": combatant1.health - combatants[combatant1.id].health,
        "Combatant 2": combatant2.health,
        "Change 2": combatant2.health - combatants[combatant2.id].health,
      };
      const stunChange1 =
        combatant1.stun_chance - combatants[combatant1.id].stun_chance;
      const stunChange2 =
        combatant2.stun_chance - combatants[combatant2.id].stun_chance;
      table["Stun Chance"] = {
        "Combatant 1": combatant1.stun_chance,
        "Change 1": stunChange1 < 0 ? "R" : stunChange1,
        "Combatant 2": combatant2.stun_chance,
        "Change 2": stunChange2 < 0 ? "R" : stunChange2,
      };
      table["Strength"] = {
        "Combatant 1": combatant1.stats.strength,
        "Change 1":
          combatant1.stats.strength - combatants[combatant1.id].stats.strength,
        "Combatant 2": combatant2.stats.strength,
        "Change 2":
          combatant2.stats.strength - combatants[combatant2.id].stats.strength,
      };
      table["Vitality"] = {
        "Combatant 1": combatant1.stats.vitality,
        "Change 1":
          combatant1.stats.vitality - combatants[combatant1.id].stats.vitality,
        "Combatant 2": combatant2.stats.vitality,
        "Change 2":
          combatant2.stats.vitality - combatants[combatant2.id].stats.vitality,
      };
      table["Dexterity"] = {
        "Combatant 1": combatant1.stats.dexterity,
        "Change 1":
          combatant1.stats.dexterity -
          combatants[combatant1.id].stats.dexterity,
        "Combatant 2": combatant2.stats.dexterity,
        "Change 2":
          combatant2.stats.dexterity -
          combatants[combatant2.id].stats.dexterity,
      };
      table["Luck"] = {
        "Combatant 1": combatant1.stats.luck,
        "Change 1":
          combatant1.stats.luck - combatants[combatant1.id].stats.luck,
        "Combatant 2": combatant2.stats.luck,
        "Change 2":
          combatant2.stats.luck - combatants[combatant2.id].stats.luck,
      };
      combatants[combatant1.id] = combatant1;
      combatants[combatant2.id] = combatant2;
      console.table(table);
    }
  }
};

if (process.argv[1] === import.meta.filename) {
  await main();
}
