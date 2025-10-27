import { parseIdTagAttackStructs } from "./loadout.js";
import { loadJson } from "./stark-utils.js";

const main = () => {
  const testActions = loadJson("./post-deploy-config/attacks.json").attacks;
  console.log(testAttacks);
  console.log("Testing attack parsing:");
  const parsedAttacks = parseIdTagAttackStructs(testAttacks);
  console.log(parsedAttacks);
  console.log("All tests passed!");
};

if (process.argv[1] === import.meta.filename) {
  main();
}
