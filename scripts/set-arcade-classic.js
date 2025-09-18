import { loadJson } from "./stark-utils.js";
import { loadSai } from "./sai.js";
import { parseIdTagAttackStructs } from "./loadout.js";

export const makeOpponentStruct = (opponent) => {
  for (let i = 0; i < 4 - opponent.attacks.length; i++) {
    opponent.attacks.push({ id: BigInt(0) });
  }
  return {
    attributes: opponent.attributes,
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
    contract.populate("set_cost", {
      energy: BigInt(config.energy_cost),
      credit: BigInt(config.credit_cost),
    }),
    contract.populate("set_health_regen_percent", {
      health_regen_percent: BigInt(config.health_regen_percent),
    }),
  ];
};

export const makeArcadeClassicCalls = async (sai) => {
  const arcadeClassicData = loadJson(
    "./post-deploy-config/arcade-classic.json"
  );
  const contract = await sai.getContract("arcade_classic");
  return [
    makeOpponentCall(contract, arcadeClassicData.opponents),
    ...makeSetConfigCalls(contract, arcadeClassicData),
  ];
};

const main = async () => {
  const sai = await loadSai();
  sai.loadManifest();
  const calls = await makeArcadeClassicCalls(sai);
  await sai.account.execute(calls);
};

if (process.argv[1] === import.meta.filename) {
  await main();
}
