import { makeSetCombatClassHashCall } from "./combat.js";
import { loadSai } from "./sai.js";

export const makePvpCalls = async (sai) => {
  const contract = await sai.getContract("pvp");
  return [makeSetCombatClassHashCall(contract, sai.classes.combat.class_hash)];
};

const main = async () => {
  const sai = await loadSai();
  sai.loadManifest();
  const calls = await makePvpCalls(sai);
  await sai.account.execute(calls);
};

if (process.argv[1] === import.meta.filename) {
  await main();
}
