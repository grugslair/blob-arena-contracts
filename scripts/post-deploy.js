import {
  loadJson,
  splitCallDescriptions,
  loadAccountManifestFromCmdArgs,
  batchCalls,
} from "./stark-utils.js";
import {
  makeClassicBlobertSeedCalls,
  makeClassicBlobertCustomCalls,
  makeAmmaBlobertCustomCalls,
} from "./update-attributes.js";
import { makePveOpponentsCalls, makePveChallengeCalls } from "./update-pve.js";
import { makeRoleCalls } from "./update-roles.js";

const main = async () => {
  const account_manifest = await loadAccountManifestFromCmdArgs();
  let pve_data = loadJson("../post-deploy-config/pve.json");

  const calls_metas = [
    ...(await makeRoleCalls(account_manifest)),
    ...(await makeClassicBlobertSeedCalls(account_manifest)),
    ...(await makeClassicBlobertCustomCalls(account_manifest)),
    ...(await makeAmmaBlobertCustomCalls(account_manifest)),
    ...(await makePveOpponentsCalls(account_manifest, pve_data.opponents)),
    ...(await makePveChallengeCalls(account_manifest, pve_data.challenges)),
  ];
  for (const calls_metas_batch of batchCalls(calls_metas, 150)) {
    const [calls, descriptions] = splitCallDescriptions(calls_metas_batch);
    console.log(descriptions);
    const transaction_hash = await account_manifest.execute(calls);
    console.log(transaction_hash);
  }
};

await main();
