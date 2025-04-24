import { loadAccountManifestFromCmdArgs, newAccount } from "../stark-utils.js";
import {
  freeBlobertContractTag,
  adminContractTag,
  arcadeContractTag,
} from "../contract-defs.js";

import { bigIntToHex } from "web3-eth-accounts";
import { mintFreeTokensWithAttacks } from "./classic-blobert.js";
import {
  mintPaidArcadeGames,
  runArcadeChallengeGames,
  startArcadeChallenges,
} from "./arcade.js";
import { getAttacks } from "./attacks.js";
import { DojoParser } from "../dojo.js";
import { dojoNamespaceMap } from "./game.js";

const accountClassHash =
  "0x07489e371db016fcd31b78e49ccd201b93f4eab60af28b862390e800ec9096e2";

const main = async () => {
  const account_manifest = await loadAccountManifestFromCmdArgs();
  const caller = account_manifest.account;
  const freeContract = await account_manifest.getContract(
    freeBlobertContractTag
  );
  const arcadeContract = await account_manifest.getContract(arcadeContractTag);
  const adminContract = await account_manifest.getContract(adminContractTag);
  const worldContract = await account_manifest.getWorldContract();
  const signer = await newAccount(caller, accountClassHash);
  const classicChallengeId = await arcadeContract.challenge_id_from_tag(
    "Classic Season 0"
  );
  await mintPaidArcadeGames(caller, arcadeContract, signer.address, 1000);
  const tokens = await mintFreeTokensWithAttacks(
    caller,
    signer,
    freeContract,
    10
  );
  console.log(tokens);
  let attackIds = new Set();
  console.log("Tokens minted");
  tokens.forEach((token) => token.attacks.forEach(attackIds.add, attackIds));
  const attacks = await getAttacks(
    worldContract,
    adminContract,
    Array.from(attackIds).map(bigIntToHex)
  );
  const dojoParser = new DojoParser(adminContract, dojoNamespaceMap);

  const challenges = await startArcadeChallenges(
    caller,
    signer,
    arcadeContract,
    classicChallengeId,
    tokens
  );

  while (challenges.some((c) => c.status === "Active")) {
    await runArcadeChallengeGames(
      caller,
      signer,
      arcadeContract,
      dojoParser,
      challenges,
      attacks
    );
  }
  //   let games = [];
  //   for (const account of accounts) {
  //     const game = {
  //         account: account,
  //         token: await mintFreeTokenWithAttacks(caller, account, freeContract),
  //         challenge_id:
  //     }
  //   }
};

if (process.argv[1] === import.meta.filename) {
  await main();
}
