import {
  loadJson,
  splitCallDescriptions,
  loadAccountManifestFromCmdArgs,
  makeCairoEnum,
  loadAccountManifest,
} from "./stark-utils.js";
import {
  arcadeContractTag,
  setUnlockableGamesEntrypoint,
} from "./contract-defs.js";
import yargs from "yargs";
import { hideBin } from "yargs/helpers";
import { hash, byteArray, CallData, shortString } from "starknet";
export const makeUnlockableGamesCalls = async (
  account_manifest,
  password,
  amount
) => {
  const contract = await account_manifest.getContract(arcadeContractTag);
  let calls = [];
  const bytes = byteArray.byteArrayFromString(password);
  const code = hash.computePoseidonHashOnElements(
    CallData.compile([
      shortString.encodeShortString("salt from mediterranean"),
      byteArray.byteArrayFromString(password),
    ])
  );

  calls = [
    [
      contract.populate(setUnlockableGamesEntrypoint, {
        code,
        amount,
      }),
      { description: `Password deployed: ${password}` },
    ],
  ];

  return calls;
};

const main = async () => {
  const argv = yargs(hideBin(process.argv))
    .usage("Usage: $0 <profile> <unlock-password> <amount> [options]")
    .positional("profile", {
      describe: 'The Scarb profile to use (e.g., "release", "sepolia")',
      type: "string",
    })
    .positional("unlock-password", {
      describe: "Unlock password for the game tokens",
      type: "string",
    })
    .positional("amount", {
      describe: "Amount of game tokens to unlock",
      type: "number",
    })
    .option("password", {
      alias: "p",
      type: "string",
      describe:
        "Password for the keystore (required if --private_key is not provided)",
      default: null,
    })
    .option("private_key", {
      alias: "k",
      type: "string",
      describe:
        "Hex-encoded private key (required if --password is not provided)",
      default: null,
    })
    .check((argv) => {
      console.log(argv);
      if (!argv.password && !argv.private_key) {
        throw new Error("You must provide either --password or --private_key.");
      }
      console.log(argv);
      const [profile, unlock_password, amount] = argv._;
      Object.assign(argv, { profile, unlock_password, amount });
      return true;
    })
    .demandCommand(3, "You must provide: <profile> <unlock-password> <amount>")
    .strict().argv;

  const account_manifest = await loadAccountManifest(
    argv.profile,
    argv.password,
    argv.private_key
  );
  const calls_metas = await makeUnlockableGamesCalls(
    account_manifest,
    argv.unlock_password,
    argv.amount
  );
  const [calls, descriptions] = splitCallDescriptions(calls_metas);
  console.log(descriptions);
  account_manifest.execute(calls).then((res) => {
    console.log(res.transaction_hash);
  });
};

if (process.argv[1] === import.meta.filename) {
  await main();
}
