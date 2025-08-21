import { loadJson } from "./stark-utils.js";
import { loadSai } from "./sai.js";

export const makeArenaCreditCalls = async (sai) => {
  const config = loadJson("./post-deploy-config/arena-credit.json");
  const profileConfig = config.profiles[sai.profile];
  const creditContract = await sai.getContract("arena_credit");
  const purchaseContract = await sai.getContract("arena_credit_purchase");

  return [
    creditContract.populate("set_max_energy", {
      max_energy: BigInt(config.max_energy),
    }),
    purchaseContract.populate("set_micro_usd_price", {
      price: BigInt(config.credit_price_usd * 1_000_000),
    }),
    purchaseContract.populate("set_wallet_address", {
      wallet_address: profileConfig.wallet_address,
    }),
    purchaseContract.populate("set_pragma_contract_address", {
      contract_address: profileConfig.pragma_contract_address,
    }),
    ...Object.values(profileConfig.price_pairs).map(
      ({ erc20_address, price_pair }) =>
        purchaseContract.populate("set_price_pair", {
          erc20_address,
          price_pair,
        })
    ),
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
