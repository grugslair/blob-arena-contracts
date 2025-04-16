import {
  loadJson,
  splitCallDescriptions,
  loadAccountManifestFromCmdArgs,
  makeCairoEnum,
} from "./stark-utils.js";
import { adminContractTag, setPermissionsEntrypoint } from "./contract-defs.js";
import { pascalCase } from "pascal-case";
export const makeRoleCalls = async (account_manifest) => {
  const role_data =
    loadJson("../post-deploy-config/roles.json")[account_manifest.profile] ||
    {};
  const contract = await account_manifest.getContract(adminContractTag);
  let calls = [];
  for (const [role, users] of Object.entries(role_data)) {
    calls.push([
      contract.populate(setPermissionsEntrypoint, {
        users,
        role: makeCairoEnum(pascalCase(role)),
        has: true,
      }),
      { description: `role: ${role}` },
    ]);
  }
  return calls;
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
