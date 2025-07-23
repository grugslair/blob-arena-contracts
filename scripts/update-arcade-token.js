import {
  loadJson,
  splitCallDescriptions,
  loadAccountManifestFromCmdArgs,
} from "./stark-utils.js";
import {
  arcadeContractTag,
  setPragmaContractAddressEntrypoint,
  setPricePairEntrypoint,
  setTokenMicroUsdPriceEntrypoint,
  setWalletAddressEntrypoint,
} from "./contract-defs.js";

export const makeArcadeTokenCalls = async (account_manifest) => {
  const arcadeTokenData =
    loadJson("./post-deploy-config/arcade-tokens.json")[
      account_manifest.profile
    ] || {};
  const contract = await account_manifest.getContract(arcadeContractTag);
  let calls = [];
  calls.push([
    contract.populate(setPragmaContractAddressEntrypoint, {
      contract_address: arcadeTokenData.pragma_contract_address,
    }),
    { description: `Pragma Token Address` },
  ]);
  const price = BigInt(arcadeTokenData.token_price_usd * 1_000_000);
  calls.push([
    contract.populate(setTokenMicroUsdPriceEntrypoint, { price }),
    { description: `Token Micro USD Price` },
  ]);
  calls.push([
    contract.populate(setWalletAddressEntrypoint, {
      wallet_address: arcadeTokenData.wallet_address,
    }),
    { description: `Wallet Address` },
  ]);
  for (const [token, data] of Object.entries(
    arcadeTokenData.price_pairs || {}
  )) {
    calls.push([
      contract.populate(setPricePairEntrypoint, data),
      { description: `token price pair: ${token}` },
    ]);
  }
  return calls;
};

const main = async () => {
  const account_manifest = await loadAccountManifestFromCmdArgs();
  const calls_metas = await makeArcadeTokenCalls(account_manifest);
  const [calls, descriptions] = splitCallDescriptions(calls_metas);
  console.log(descriptions);
  account_manifest.execute(calls).then((res) => {
    console.log(res.transaction_hash);
  });
};

if (process.argv[1] === import.meta.filename) {
  await main();
}
