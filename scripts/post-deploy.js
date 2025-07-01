import {
  loadJson,
  splitCallDescriptions,
  loadAccountManifestFromCmdArgs,
  batchCalls,
} from "./stark-utils.js";
import {
  makeClassicBlobertSeedCalls,
  makeClassicBlobertCustomCalls,
  makeAmmaBlobertCalls,
} from "./update-attributes.js";
import {
  makeArcadeOpponentsCalls,
  makeArcadeChallengeCalls,
  setAmmaCollectionAddress,
} from "./update-arcade.js";
import { makeRoleCalls } from "./update-roles.js";
import { makeAchievementsCalls } from "./update-achievements.js";

const main = async () => {
  const account_manifest = await loadAccountManifestFromCmdArgs();
  let arcade_data = loadJson("./post-deploy-config/arcade.json");

  const calls_metas = [
    ...(await makeRoleCalls(account_manifest)),
    ...(await makeClassicBlobertSeedCalls(account_manifest)),
    ...(await makeClassicBlobertCustomCalls(account_manifest)),
    ...(await makeAmmaBlobertCalls(account_manifest)),
    ...(await makeArcadeOpponentsCalls(
      account_manifest,
      arcade_data.opponents
    )),
    ...(await makeArcadeChallengeCalls(
      account_manifest,
      arcade_data.challenges
    )),
    ...(await setAmmaCollectionAddress(account_manifest)),
    ...(await makeAchievementsCalls(account_manifest)),
  ];
  for (const calls_metas_batch of batchCalls(calls_metas, 50)) {
    const [calls, descriptions] = splitCallDescriptions(calls_metas_batch);
    console.log(descriptions);
    const transaction_hash = await account_manifest.execute(calls);
    console.log(transaction_hash);
  }
};

await main();
