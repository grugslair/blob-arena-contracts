import { loadAccountManifestFromCmdArgs, newAccounts } from "../stark-utils.js";
import { randomIndexes } from "../utils.js";
import {
  freeBlobertContractTag,
  lobbyContractTag,
  pvpContractTag,
  adminContractTag,
} from "../contract-defs.js";
import { makeLobby } from "./lobby.js";
import { runPvpBattles } from "./pvp.js";
import { bigIntToHex } from "web3-eth-accounts";
import {
  mintFreeTokensWithAttacks,
  mintFreeTokenWithAttacks,
} from "./classic-blobert.js";
import { getAttacks } from "./attacks.js";
import { printRoundResults } from "./game.js";

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

  const player1Tokens = await mintFreeTokensWithAttacks(
    account,
    account1,
    freeContract,
    5
  );
  const player2Tokens = await mintFreeTokensWithAttacks(
    account,
    account2,
    freeContract,
    5
  );
  let allAttackIds = new Set();
  player1Tokens.forEach((token) =>
    token.attacks.forEach(allAttackIds.add, allAttackIds)
  );
  player2Tokens.forEach((token) =>
    token.attacks.forEach(allAttackIds.add, allAttackIds)
  );

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
        token1.id,
        attackSlots1,
        token2.id,
        attackSlots2
      );

      const combatant1 = {
        id: combatantId1,
        token_id: token1.id,
        attacks: Object.fromEntries(attacks1.map((a) => [a, 0])),
        attack_slots: attackSlots1,
        stats: await gameContract.combatant_stats(combatantId1),
        health: await gameContract.combatant_health(combatantId1),
        stun_chance: BigInt(0),
      };
      const combatant2 = {
        id: combatantId2,
        token_id: token2.id,
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
  await runPvpBattles(
    worldContract,
    account,
    account1,
    account2,
    gameContract,
    games,
    attacks
  );
  for (const game of games) {
    printRoundResults(game);
  }
};

if (process.argv[1] === import.meta.filename) {
  await main();
}
