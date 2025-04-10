import {
  loadJson,
  splitCallDescriptions,
  loadAccountManifest,
  makeCairoEnum,
  pascalCase,
} from "./stark-utils.js";
import commandLineArgs from "command-line-args";
import {
  gameAdminContractTag,
  setPermissionsEntrypoint,
} from "./contract-defs.js";

export const makeRoleCalls = async (account_manifest, profile) => {
  const role_data =
    loadJson("../post-deploy-config/roles.json")[account_manifest.profile] ||
    {};
  const contract = await account_manifest.getContract(gameAdminContractTag);
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
  const optionDefinitions = [
    { name: "profile", type: String, defaultOption: true },
    { name: "password", alias: "p", type: String },
  ];
  const options = commandLineArgs(optionDefinitions);

  const account_manifest = await loadAccountManifest(
    options.profile,
    options.password
  );

  const calls_metas = await makeRoleCalls(account_manifest, options.profile);
  const [calls, descriptions] = splitCallDescriptions(calls_metas);
  console.log(descriptions);
  account_manifest.execute(calls).then((res) => {
    console.log(res.transaction_hash);
  });
};

if (process.argv[1] === import.meta.filename) {
  await main();
}
