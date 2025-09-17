import { loadJson } from "./stark-utils.js";
import { loadSai } from "./sai.js";

export const makeSetConfigCalls = (contract, config) => {};

export const makeArcadeAmmaCalls = async (sai) => {
  const config = loadJson("./post-deploy-config/arcade-amma.json");
  const contract = await sai.getContract("arcade_amma");
  return [
    contract.populate("set_max_respawns", {
      max_respawns: BigInt(config.max_respawns),
    }),
    contract.populate("set_time_limit", {
      time_limit: BigInt(config.time_limit),
    }),
    contract.populate("set_health_regen_percent", {
      health_regen_percent: BigInt(config.health_regen_percent),
    }),
    contract.populate("set_cost", {
      energy: BigInt(config.energy_cost),
      credit: BigInt(config.credit_cost),
    }),
    contract.populate("set_gen_stages", {
      gen_stages: BigInt(config.generated_stages),
    }),
  ];
};

const main = async () => {
  const sai = await loadSai();
  sai.loadManifest();
  const calls = await makeArcadeAmmaCalls(sai);
  await sai.account.execute(calls);
};

if (process.argv[1] === import.meta.filename) {
  await main();
}
