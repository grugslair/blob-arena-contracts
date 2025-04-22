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
import { mintFreeTokenWithAttacks } from "./classic-blobert.js";
const classicChallengeId =
  "0x033bd13f2718e9b2a90b3b8c7847b11c9eb5ce81c95009998380ab95b343f53d";

const accountClassHash =
  "0x07489e371db016fcd31b78e49ccd201b93f4eab60af28b862390e800ec9096e2";

const makeAttack = (caller, signer, attacks) => {};

const main = async () => {
  const account_manifest = await loadAccountManifestFromCmdArgs();
  const account = account_manifest.account;
  const freeContract = await account_manifest.getContract(
    freeBlobertContractTag
  );
  const lobbyContract = await account_manifest.getContract(lobbyContractTag);
  const arcadeContract = await account_manifest.getContract(arcadeContractTag);

  console.log("Deploying new accounts");
  const account1 = await newAccount(account, accountClassHash);
  console.log("Accounts deployed");
  const playerTokens = [];
  for (let i = 0; i < 6; i++) {
    playerTokens.push(
      await mintFreeTokenWithAttacks(account, account1, freeContract)
    );
  }
  let games = [];

  for (let i = 0; i < playerTokens.length; i++) {}
};

if (process.argv[1] === import.meta.filename) {
  await main();
}
