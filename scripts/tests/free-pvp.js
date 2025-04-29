import { loadAccountManifestFromCmdArgs, newAccounts } from "../stark-utils.js";
import { randomIndexes } from "../utils.js";
import {
  freeBlobertContractTag,
  lobbyContractTag,
  pvpContractTag,
  adminContractTag,
} from "../contract-defs.js";
import { makeLobbies } from "./lobby.js";
import { runPvpBattles } from "./pvp.js";
import { bigIntToHex } from "web3-eth-accounts";
import { mintFreeTokensWithAttacks } from "./classic-blobert.js";
import { getAttacks, makeAttack } from "./attacks.js";
import { dojoNamespaceMap, printRoundResults } from "./game.js";
import { DojoParser } from "../dojo.js";

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
  player1Tokens.map((t) => t.attacks.map((a) => allAttackIds.add(a.id)));
  player2Tokens.map((t) => t.attacks.map((a) => allAttackIds.add(a.id)));
  const dojoParser = new DojoParser(adminContract, dojoNamespaceMap);
  const attacks = await getAttacks(
    worldContract,
    adminContract,
    Array.from(allAttackIds).map(bigIntToHex)
  );
  let wins = { 0: 0 };
  let n = 0;
  let games = [];
  for (let i = 0; i < player1Tokens.length; i++) {
    const token1 = player1Tokens[i];
    wins[i + 1] = 0;
    for (let j = 0; j < player2Tokens.length; j++) {
      const token2 = player2Tokens[j];
      const indexes1 = randomIndexes(token1.attacks.length, 4);
      const indexes2 = randomIndexes(token2.attacks.length, 4);
      games.push({
        n: ++n,
        accounts: [account1, account2],
        round: 1,
        winner: null,
        rounds: [],
        combatants: [
          {
            token: token1,
            token_id: token1.id,
            attacks: indexes1.map((index) =>
              makeAttack(token1.attacks[index], attacks)
            ),
            stats: token1.stats,
            health: token1.stats.vitality + BigInt(100),
            stun_chance: BigInt(0),
          },
          {
            token: token2,
            token_id: token2.id,
            attacks: indexes2.map((index) =>
              makeAttack(token2.attacks[index], attacks)
            ),
            stats: token2.stats,
            health: token2.stats.vitality + BigInt(100),
            stun_chance: BigInt(0),
          },
        ],
      });
    }
  }
  await makeLobbies(lobbyContract, gameContract, account, games);

  console.log("Games created");
  await runPvpBattles(
    dojoParser,
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
