import { loadJson } from "./stark-utils.js";
import { loadSai } from "./sai.js";
import { parseIdTagAttackStructs, parsePartialAttributes } from "./loadout.js";
import { makeSetCombatClassHashCall } from "./combat.js";
import { makeArcadeConfigCalls } from "./arcade.js";
export const makeOpponentStruct = (opponent) => {
  return {
    base: parsePartialAttributes(opponent.base),
    level: parsePartialAttributes(opponent.level),
    attacks: parseIdTagAttackStructs(opponent.attacks),
  };
};

export const makeOpponentsCall = (contract, opponents) => {
  return contract.populate("set_opponents", {
    opponents: opponents.map(makeOpponentStruct),
  });
};

export const makeSetArcadeAmmaConfigCalls = (contract, config) => {
  return [
    contract.populate("set_gen_stages", {
      gen_stages: BigInt(config.generated_stages),
    }),
  ];
};

export const makeArcadeAmmaCalls = async (sai) => {
  const arcadeAmmaData = loadJson("./post-deploy-config/arcade-amma.json");
  const contract = await sai.getContract("arcade_amma");
  return [
    makeSetCombatClassHashCall(contract, sai.classes.combat.class_hash),
    makeOpponentsCall(contract, arcadeAmmaData.opponents),
    ...makeSetArcadeAmmaConfigCalls(contract, arcadeAmmaData),
    ...makeArcadeConfigCalls(sai, contract, arcadeAmmaData),
  ];
};

const main = async () => {
  const sai = await loadSai();
  sai.loadManifest();
  const calls = await makeArcadeAmmaCalls(sai);
  await sai.account.execute(calls);
};

if (process.argv[1] === import.meta.filename) {
  await main();
}
