import {
  loadAccountManifestFromCmdArgs,
  newAccount,
  callOptions,
} from "../stark-utils.js";
import {
  freeBlobertContractTag,
  adminContractTag,
  arcadeAmmaContractTag,
  arcadeContractTag,
  ammaBlobertContractTag,
} from "../contract-defs.js";

import { bigIntToHex } from "web3-eth-accounts";
import { mintFreeTokensWithAttacks } from "./classic-blobert.js";
import {
  ChallengeAttempt,
  mintPaidArcadeGames,
  runArcadeChallengeGames,
  startArcadeChallenges,
  runArcadeChallengeNextRounds,
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
import { ammaFighterIds, mintAmmaTokensWithAttacks } from "./amma-blobert.js";

const accountClassHash =
  "0x07489e371db016fcd31b78e49ccd201b93f4eab60af28b862390e800ec9096e2";

const generateBoss = async (caller, challenge) => {
  console.log("Generating boss");
  const calls = [
    challenge.signer.getOutsideTransaction(
      callOptions(caller.address),
      challenge.contract.populate("generate_boss", {
        attempt_id: challenge.attemptId,
      })
    ),
  ];
  const { transaction_hash } = await caller.executeFromOutside(
    await Promise.all(calls),
    {
      version: 3,
    }
  );
  challenge.bossGenerated = true;
};

const main = async () => {
  const account_manifest = await loadAccountManifestFromCmdArgs();
  const caller = account_manifest.account;
  const ammaContract = await account_manifest.getContract(
    ammaBlobertContractTag
  );
  const arcadeContract = await account_manifest.getContract(
    arcadeAmmaContractTag
  );
  const arcadeAdminContract = await account_manifest.getContract(
    arcadeContractTag
  );
  const gameContract = await account_manifest.getContract(adminContractTag);
  const worldContract = await account_manifest.getWorldContract();
  const accountClassHash = await declareAccountContract(account_manifest);
  const signer = await newAccount(caller, accountClassHash);
  const classicChallengeId = BigInt(0);
  await mintPaidArcadeGames(caller, arcadeAdminContract, signer.address, 1000);
  const tokens = await mintAmmaTokensWithAttacks(caller, signer, ammaContract);
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
        `${challenge.status} Stage: ${challenge.stage} Opponent: ${
          challenge.currentGame.opponentToken
        } Round: ${challenge.currentGame.round} Respawns: ${
          challenge.respawns
        } attack: ${allAttacks.attacks[challenge.lastAttack].name}`
      );
      if (
        challenge.stage === 9 &&
        challenge.currentGame.phase == "PlayerWon" &&
        !challenge.bossGenerated
      ) {
        await generateBoss(caller, challenge);
      }
    }
    await runArcadeChallengeNextRounds(caller, challenges);
    rounds.push(getRoundResults(caller, dojoParser, transaction_hash));
  }
  console.log("Challenges finished");
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
