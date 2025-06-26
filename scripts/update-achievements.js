import {
  loadJson,
  splitCallDescriptions,
  loadAccountManifestFromCmdArgs,
  makeCairoEnum,
} from "./stark-utils.js";
import {
  adminContractTag,
  createAchievementsEntrypoint,
} from "./contract-defs.js";

export const parseTast = (data) => {
  return {
    ...data,
    id: makeCairoEnum(data.id),
  };
};
export const parseAchievement = (id, data) => {
  return {
    id,
    ...data,
    tasks: data.tasks.map(parseTast),
  };
};

export const makeAchievementsCalls = async (account_manifest) => {
  const achievements_data = loadJson("./post-deploy-config/achievements.json");
  const contract = await account_manifest.getContract(adminContractTag);
  let achievements = Object.entries(achievements_data).map(([id, data]) =>
    parseAchievement(id, data)
  );
  return [
    [
      contract.populate(createAchievementsEntrypoint, { achievements }),
      { description: `achievements` },
    ],
  ];
};

const main = async () => {
  const account_manifest = await loadAccountManifestFromCmdArgs();
  const calls_metas = await makeAchievementsCalls(account_manifest);
  const [calls, descriptions] = splitCallDescriptions(calls_metas);
  console.log(descriptions);
  const res = await account_manifest.execute(calls);
  console.log(res.transaction_hash);
};

if (process.argv[1] === import.meta.filename) {
  await main();
}
