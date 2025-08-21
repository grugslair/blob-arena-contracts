import { loadJson } from "./stark-utils.js";
import { loadSai } from "./sai.js";

export const makeArenaCreditCalls = async (sai) => {
  const config = loadJson("./post-deploy-config/arena-credit.json");
  const contract = await sai.getContract("arena_credit");
  return [
    contract.populate("set_max_energy", {
      max_energy: BigInt(config.max_energy),
    }),
  ];
};

const main = async () => {
  const sai = await loadSai();
  sai.loadManifest();
  await sai.account.execute(await makeArenaCreditCalls(sai));
};

if (process.argv[1] === import.meta.filename) {
  await main();
}
