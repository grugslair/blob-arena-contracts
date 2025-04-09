import {
  loadJson,
  splitCallDescriptions,
  loadAccountManifest,
  batchCalls,
} from "./stark-utils.js";

import commandLineArgs from "command-line-args";

import {
  makeClassicBlobertSeedCalls,
  makeClassicBlobertCustomCalls,
  makeAmmaBlobertCustomCalls,
} from "./update-attributes.js";
import {
  makeArcadeOpponentsCalls,
  makeArcadeChallengeCalls,
} from "./update-arcade.js";
import { makeRoleCalls } from "./update-roles.js";

const main = async () => {
  const optionDefinitions = [
    { name: "profile", type: String, defaultOption: true },
    { name: "password", alias: "p", type: String },
  ];
  const options = commandLineArgs(optionDefinitions);

  const account_manifest = await loadAccountManifest(
    options.profile,
    options.password
  );
  let arcade_data = loadJson("../post-deploy-config/arcade.json");

  const calls_metas = [
    ...(await makeRoleCalls(account_manifest, options.profile)),
    ...(await makeClassicBlobertSeedCalls(account_manifest)),
    ...(await makeClassicBlobertCustomCalls(account_manifest)),
    ...(await makeAmmaBlobertCustomCalls(account_manifest)),
    ...(await makeArcadeOpponentsCalls(
      account_manifest,
      arcade_data.opponents
    )),
    ...(await makeArcadeChallengeCalls(
      account_manifest,
      arcade_data.challenges
    )),
  ];
  for (const calls_metas_batch of batchCalls(calls_metas, 70)) {
    const [calls, descriptions] = splitCallDescriptions(calls_metas_batch);
    console.log(descriptions);
    const res = await account_manifest.execute(calls);
    console.log(res.transaction_hash);
  }
};

await main();
