import { loadJson, makeCairoEnum } from "./stark-utils.js";
import { CairoCustomEnum } from "starknet";
import { loadSai } from "./sai.js";
import { parseIdTagActionStructs, parsePartialAttributes } from "./loadout.js";
import pkg from "case";
const { pascal } = pkg;
const SET_CALLS = 10;
// export const parseBlobertItemKey = (itemKey) => {
//   const [key, value] = Object.entries(itemKey)[0];
//   if (key == "Seed") {
//     return new CairoCustomEnum({
//       Seed: {
//         attribute: new CairoCustomEnum({ [value.attribute]: {} }),
//         attribute_id: value.attribute_id,
//       },
//     });
//   }
//   if (key == "Custom") {
//     return new CairoCustomEnum({ Custom: value });
//   }
// };

const makeSeedItemCallData = (trait, n, item) => {
  const trait_str = pascal(trait);
  try {
    return {
      blobert_trait: makeCairoEnum({ [trait_str]: {} }),
      index: BigInt(n),
      name: item.name,
      attributes: parsePartialAttributes(item.attributes),
      actions: parseIdTagActionStructs(item.actions),
    };
  } catch (e) {
    console.error(`Error processing item: ${trait} ${n}, ${item.name}`);
    throw e;
  }
};
const Traits = ["armour", "background", "jewelry", "mask", "weapon"];
export const makeLoadoutsClassic = async (sai) => {
  const seed_data = loadJson("./post-deploy-config/loadouts-classic.json");
  const contract = await sai.getContract("loadout_classic");

  let loadouts = [];
  for (const trait of Traits) {
    for (const [n, item] of Object.entries(seed_data[trait])) {
      loadouts.push(makeSeedItemCallData(trait, n, item));
    }
  }
  const split_loadouts = new Array(Math.ceil(loadouts.length / SET_CALLS))
    .fill()
    .map((_) => loadouts.splice(0, SET_CALLS));

  return split_loadouts.map((loadouts) =>
    contract.populate("set_loadouts", { loadouts })
  );
};

const main = async () => {
  const sai = await loadSai();
  sai.loadManifest();
  const calls = await makeLoadoutsClassic(sai);
  for (const call of calls) await sai.executeAndWait(call);
};

if (process.argv[1] === import.meta.filename) {
  await main();
}
