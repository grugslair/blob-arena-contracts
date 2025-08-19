import { loadJson, makeCairoEnum } from "./stark-utils.js";
import { CairoCustomEnum } from "starknet";
import { loadSai } from "./sai.js";
import { parseIdTagAttackStructs } from "./attack.js";

export const parseBlobertItemKey = (itemKey) => {
  const [key, value] = Object.entries(itemKey)[0];
  if (key == "Seed") {
    return new CairoCustomEnum({
      Seed: {
        attribute: new CairoCustomEnum({ [value.attribute]: {} }),
        attribute_id: value.attribute_id,
      },
    });
  }
  if (key == "Custom") {
    return new CairoCustomEnum({ Custom: value });
  }
};

const makeSeedItemCallData = (trait, n, item) => {
  const trait_str = trait.charAt(0).toUpperCase() + trait.slice(1);
  return {
    key: makeCairoEnum({ [trait_str]: Number(n) }),
    name: item.name,
    abilities: item.abilities,
    attacks: parseIdTagAttackStructs(item.attacks),
  };
};

export const makeBlobertLoadouts = async (sai) => {
  const seed_data = loadJson("./post-deploy-config/classic-loadouts.json");
  const contract = await sai.getContract("classic_blobert_loadout");

  let loadouts = [];
  for (const [trait, traits] of Object.entries(seed_data)) {
    for (const [n, item] of Object.entries(traits)) {
      loadouts.push(makeSeedItemCallData(trait, n, item));
    }
  }
  return contract.populate("set_loadouts", { loadouts });
};

const main = async () => {
  const sai = await loadSai();
  sai.loadManifest();
  const call = await makeBlobertLoadouts(sai);
  await sai.account.execute(call);
};

if (process.argv[1] === import.meta.filename) {
  await main();
}
