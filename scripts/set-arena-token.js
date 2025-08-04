import { loadJson } from "./stark-utils.js";
import { loadSai } from "./sai.js";

export const makeArenaBlobertCalls = async (sai) => {
  const config = loadJson("./post-deploy-config/arena-token.json");
  const contract = await sai.getContract("arena_blobert_minter");
  return [
    contract.populate("set_min_mint_time", {
      min_mint_time: BigInt(config.min_mint_time),
    }),
    contract.populate("set_max_bloberts", {
      max_bloberts: BigInt(config.max_bloberts),
    }),
  ];
};

const main = async () => {
  const sai = await loadSai();
  sai.loadManifest();
  const calls = await makeArenaBlobertCalls(sai);
  await sai.account.execute(calls);
};

if (process.argv[1] === import.meta.filename) {
  await main();
}
