import {
  loadJson,
  splitCallDescriptions,
  loadAccountManifestFromCmdArgs,
  makeCairoEnum,
} from "./stark-utils.js";
import {
  arcadeContractTag,
  arcadeAmmaContractTag,
  setMaxRespawnsEntrypoint,
  setGameEnergyCostEntrypoint,
  setTimeLimitEntrypoint,
} from "./contract-defs.js";

export const makeArcadeConfigCalls = async (account_manifest) => {
  const data = loadJson("./post-deploy-config/arcade-config.json")[
    account_manifest.profile
  ];
  const classicContract = await account_manifest.getContract(arcadeContractTag);
  const ammaContract = await account_manifest.getContract(
    arcadeAmmaContractTag
  );

  return [
    [
      classicContract.populate(setMaxRespawnsEntrypoint, {
        max_respawns: data.classic.max_respawns,
      }),
      { description: `set classic max respawns ${data.classic.max_respawns}` },
    ],
    [
      ammaContract.populate(setMaxRespawnsEntrypoint, {
        max_respawns: data.amma.max_respawns,
      }),
      { description: `set amma max respawns ${data.amma.max_respawns}` },
    ],
    [
      classicContract.populate(setGameEnergyCostEntrypoint, {
        game_energy_cost: data.classic.game_energy_cost,
      }),
      {
        description: `set classic game energy cost ${data.classic.game_energy_cost}`,
      },
    ],
    [
      ammaContract.populate(setGameEnergyCostEntrypoint, {
        game_energy_cost: data.amma.game_energy_cost,
      }),
      {
        description: `set amma game energy cost ${data.amma.game_energy_cost}`,
      },
    ],
    [
      classicContract.populate(setTimeLimitEntrypoint, {
        time_limit: data.classic.time_limit,
      }),
      { description: `set classic time limit ${data.classic.time_limit}` },
    ],
    [
      ammaContract.populate(setTimeLimitEntrypoint, {
        time_limit: data.amma.time_limit,
      }),
      { description: `set amma time limit ${data.amma.time_limit}` },
    ],
  ];
};

const main = async () => {
  const account_manifest = await loadAccountManifestFromCmdArgs();
  const calls_metas = await makeRoleCalls(account_manifest);
  const [calls, descriptions] = splitCallDescriptions(calls_metas);
  console.log(descriptions);
  account_manifest.execute(calls).then((res) => {
    console.log(res.transaction_hash);
  });
};

if (process.argv[1] === import.meta.filename) {
  await main();
}
