import { loadJson } from "./stark-utils.js";
import { loadSai } from "./sai.js";
import { parseIdTagAttackStructs } from "./loadout.js";
import { parseAttributes } from "./loadout.js";

const makeFighterItemCallData = (n, data) => {
  return {
    fighter: Number(n),
    attributes: parseAttributes(data.abilities),
    attacks: parseIdTagAttackStructs(data.attacks),
  };
};

export const makeLoadoutsAmma = async (sai) => {
  const data = loadJson("./post-deploy-config/loadouts-amma.json");
  const contract = await sai.getContract("loadout_amma");

  let fighters = [];
  for (const [n, fighter] of Object.entries(data)) {
    fighters.push(makeFighterItemCallData(n, fighter));
  }
  const count = contract.fighter_count();
  if (count < fighters.length) {
  } else if (count > fighters.length) {
    console.warn(
      `Warning: Contract has ${count} fighters, but ${fighters.length} are being set.`
    );
  }
  return [
    contract.populate("set_fighters", { fighters }),
    contract.populate("set_fighter_count", { count: BigInt(fighters.length) }),
  ];
};

const main = async () => {
  const sai = await loadSai();
  sai.loadManifest();
  await sai.account.execute(await makeLoadoutsAmma(sai));
};

if (process.argv[1] === import.meta.filename) {
  await main();
}
