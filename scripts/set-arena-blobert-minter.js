import { loadJson } from "./stark-utils.js";
import { loadSai } from "./sai.js";

export const makeArenaBlobertMinterCalls = async (sai) => {
  const config = loadJson("./post-deploy-config/arena-blobert.json");
  const contract = await sai.getContract("arena_blobert_minter");
  return [
    contract.populate("set_free_tokens", {
      free_tokens: BigInt(config.free_tokens),
    }),
    contract.populate("set_max_bloberts", {
      max_bloberts: BigInt(config.max_bloberts),
    }),
    contract.populate("set_vrf_address", {
      contract_address: sai.contracts.vrf.contract_address,
    }),
    contract.populate("set_arcade_credit_address", {
      contract_address: sai.contracts.arena_credit.contract_address,
    }),
    contract.populate("set_arcade_credit_cost", {
      credit_cost: BigInt(config.credit_cost),
    }),
  ];
};

const main = async () => {
  const sai = await loadSai();
  sai.loadManifest();
  const calls = await makeArenaBlobertMinterCalls(sai);
  await sai.account.execute(calls);
};

if (process.argv[1] === import.meta.filename) {
  await main();
}
