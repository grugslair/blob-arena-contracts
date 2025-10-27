import { loadJson } from "./stark-utils.js";
import { loadSai } from "./sai.js";
import { parseAttributes, parseIdTagActionStructs } from "./loadout.js";
import { CairoCustomEnum } from "starknet";
import { makeSetCombatClassHashCall } from "./combat.js";
import { makeArcadeConfigCalls } from "./arcade.js";

export const makeOpponentStruct = (opponent) => {
  return {
    traits: new CairoCustomEnum(opponent.traits),
    attributes: parseAttributes(opponent.attributes),
    actions: parseIdTagActionStructs(opponent.actions),
  };
};

export const makeOpponentsCall = (contract, opponents) => {
  return contract.populate("set_opponents", {
    opponents: opponents.map(makeOpponentStruct),
  });
};

export const makeArcadeClassicCalls = async (sai) => {
  const arcadeClassicData = loadJson(
    "./post-deploy-config/arcade-classic.json"
  );
  const contract = await sai.getContract("arcade_classic");
  return [
    makeSetCombatClassHashCall(contract, sai.classes.combat.class_hash),
    makeOpponentsCall(contract, arcadeClassicData.opponents),
    ...makeArcadeConfigCalls(sai, contract, arcadeClassicData),
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
