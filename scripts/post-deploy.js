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
import { makePveOpponentsCalls, makePveChallengeCalls } from "./update-pve.js";
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
  let pve_data = loadJson("../post-deploy-config/pve.json");

  const calls_metas = [
    ...(await makeRoleCalls(account_manifest, options.profile)),
    ...(await makeClassicBlobertSeedCalls(account_manifest)),
    ...(await makeClassicBlobertCustomCalls(account_manifest)),
    ...(await makeAmmaBlobertCustomCalls(account_manifest)),
    ...(await makePveOpponentsCalls(account_manifest, pve_data.opponents)),
    ...(await makePveChallengeCalls(account_manifest, pve_data.challenges)),
  ];
  for (const calls_metas_batch of batchCalls(calls_metas, 70)) {
    const [calls, descriptions] = splitCallDescriptions(calls_metas_batch);
    console.log(descriptions);
    account_manifest.execute(calls).then((res) => {
      console.log(res.transaction_hash);
    });
  }
};

await main();
