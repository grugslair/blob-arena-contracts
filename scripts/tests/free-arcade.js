import {
  loadAccountManifestFromCmdArgs,
  uint256ToHex,
  getReturns,
  dataToUint256,
  newAccount,
  callOptions,
} from "../stark-utils.js";
import { randomIndexes } from "../utils.js";
import {
  freeBlobertContractTag,
  mintEntrypoint,
  lobbyContractTag,
  pvpContractTag,
  arcadeContractTag,
} from "../contract-defs.js";
import { cairo, Account, hash } from "starknet";
import { makeLobby } from "./lobby.js";
import { runRounds } from "./pvp.js";
import { bigIntToHex } from "web3-eth-accounts";
import { mintFreeTokensWithAttacks } from "./classic-blobert.js";
import {
  mintPaidArcadeGames,
  runArcadeChallengeGames,
  startArcadeChallenges,
} from "./arcade.js";
const classicChallengeId =
  "0x033bd13f2718e9b2a90b3b8c7847b11c9eb5ce81c95009998380ab95b343f53d";

const accountClassHash =
  "0x07489e371db016fcd31b78e49ccd201b93f4eab60af28b862390e800ec9096e2";
const toRun = 10;

const main = async () => {
  const account_manifest = await loadAccountManifestFromCmdArgs();
  const caller = account_manifest.account;
  const freeContract = await account_manifest.getContract(
    freeBlobertContractTag
  );
  const lobbyContract = await account_manifest.getContract(lobbyContractTag);
  const arcadeContract = await account_manifest.getContract(arcadeContractTag);

  const signer = await newAccount(caller, accountClassHash);

  await mintPaidArcadeGames(caller, arcadeContract, signer.address, 1000);
  let tokens = await mintFreeTokensWithAttacks(
    caller,
    signer,
    freeContract,
    10
  );
  tokens.map((token) => {
    let indexes = randomIndexes(token.attacks.length, 4);
    token.attacks = indexes.map((index) => token.attacks[index]);
    token.attack_slots = indexes.map((index) => token.attack_slots[index]);
  });

  const challenges = await startArcadeChallenges(
    caller,
    signer,
    arcadeContract,
    classicChallengeId,
    tokens
  );
  while (challenges.some((c) => c.status === "Active")) {
    await runArcadeChallengeGames(caller, signer, arcadeContract, challenges);
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
