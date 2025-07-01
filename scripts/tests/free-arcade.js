import { loadAccountManifestFromCmdArgs, newAccount } from "../stark-utils.js";
import {
  freeBlobertContractTag,
  adminContractTag,
  arcadeContractTag,
} from "../contract-defs.js";

import { bigIntToHex } from "web3-eth-accounts";
import { mintFreeTokensWithAttacks } from "./classic-blobert.js";
import {
  ChallengeAttempt,
  mintPaidArcadeGames,
  runArcadeChallengeGames,
  startArcadeChallenges,
} from "./arcade.js";
import { Attacks, getAttacks, makeAttack } from "./attacks.js";
import { DojoParser } from "../dojo.js";
import {
  dojoNamespaceMap,
  getRoundResults,
  printAttackResults,
  declareAccountContract,
} from "./game.js";
import { randomIndexes } from "../utils.js";

const main = async () => {
  const account_manifest = await loadAccountManifestFromCmdArgs();
  const caller = account_manifest.account;
  const freeContract = await account_manifest.getContract(
    freeBlobertContractTag
  );
  const arcadeContract = await account_manifest.getContract(arcadeContractTag);
  const gameContract = await account_manifest.getContract(adminContractTag);
  const worldContract = await account_manifest.getWorldContract();
  const accountClassHash = await declareAccountContract(account_manifest);
  const signer = await newAccount(caller, accountClassHash);
  const classicChallengeId = await arcadeContract.challenge_id_from_tag(
    "Classic Season 0"
  );
  [];
  await mintPaidArcadeGames(caller, arcadeContract, signer.address, 1000);
  const tokens = await mintFreeTokensWithAttacks(
    caller,
    signer,
    freeContract,
    10
  );
  let attackIds = new Set();
  tokens.forEach((token) =>
    token.attacks.forEach((attack) => attackIds.add(attack.id))
  );
  const allAttacks = new Attacks(worldContract, gameContract);
  await allAttacks.init();
  await allAttacks.getAttacks(Array.from(attackIds).map(bigIntToHex));

  const challenges = tokens.map((token) => {
    const attacksUsed = randomIndexes(token.attacks.length, 4).map((i) =>
      makeAttack(token.attacks[i], allAttacks.attacks)
    );
    return new ChallengeAttempt(
      signer,
      arcadeContract,
      gameContract,
      classicChallengeId,
      token,
      attacksUsed,
      allAttacks
    );
  });
  await startArcadeChallenges(caller, challenges);
  const dojoParser = new DojoParser(gameContract, dojoNamespaceMap);
  let rounds = [];
  while (challenges.some((c) => c.status === "Active")) {
    const transaction_hash = await runArcadeChallengeGames(caller, challenges);
    for (const challenge of challenges) {
      console.log(
        `${challenge.status} Stage: ${challenge.stage} Round: ${
          challenge.currentGame.round
        } Respawns: ${challenge.respawns} attack: ${
          allAttacks.attacks[challenge.lastAttack].name
        }`
      );
    }
    rounds.push(getRoundResults(caller, dojoParser, transaction_hash));
  }
  const games = Object.fromEntries(
    challenges
      .flatMap((c) => Object.values(c.games).flat())
      .map((g) => [g.id, g])
  );
  for (const { combat_id, attacks, states } of (
    await Promise.all(rounds)
  ).flat()) {
    games[combat_id].rounds.push({ attacks, states });
  }
  for (const [ci, challenge] of challenges.entries()) {
    console.log(`Challenge ${ci + 1}`);
    for (const [stage, games] of Object.entries(challenge.games)) {
      console.log(`Stage ${stage}`);
      for (const game of Object.values(games)) {
        printAttackResults(game, ["Player", "Opponent"]);
        console.log(`${game.phase}\n`);
      }
    }
  }
  // for (const game of Object.values(games)) {
  //   console.log(game);
  // }
};

if (process.argv[1] === import.meta.filename) {
  await main();
}
