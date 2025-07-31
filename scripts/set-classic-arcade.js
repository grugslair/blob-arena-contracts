import { loadJson, makeCairoEnum } from "./stark-utils.js";
import { CairoCustomEnum } from "starknet";
import { loadSai } from "./sai.js";
import { parseIdTagAttackStructs } from "./attack.js";

export const makeOpponentStruct = (opponent) => {
  for (let i = 0; i < 4 - opponent.attacks.length; i++) {
    opponent.attacks.push({ id: BigInt(0) });
  }
  return {
    attributes: opponent.attributes,
    abilities: opponent.abilities,
    attacks: parseIdTagAttackStructs(opponent.attacks),
  };
};

export const makeOpponentCall = (contract, opponents) => {
  return contract.populate("set_opponents", {
    opponents: opponents.map(makeOpponentStruct),
  });
};

export const makeSetConfigCalls = (contract, config) => {
  return [
    contract.populate("set_max_respawns", {
      max_respawns: BigInt(config.max_respawns),
    }),
    contract.populate("set_time_limit", {
      time_limit: BigInt(config.time_limit),
    }),
  ];
};

export const makeClassicArcadeCalls = async (sai) => {
  const classicArcadeData = loadJson(
    "./post-deploy-config/classic-arcade.json"
  );
  const contract = await sai.getContract("classic_arcade");
  return [
    makeOpponentCall(contract, classicArcadeData.opponents),
    ...makeSetConfigCalls(contract, classicArcadeData),
  ];
};

const main = async () => {
  const sai = await loadSai();
  sai.loadManifest();
  const calls = await makeClassicArcadeCalls(sai);
  await sai.account.execute(calls);
};

if (process.argv[1] === import.meta.filename) {
  await main();
}
