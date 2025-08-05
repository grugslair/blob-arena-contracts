import { loadSai } from "./sai.js";
import { makeClassicArcadeCalls } from "./set-classic-arcade.js";
import { stark } from "starknet";

const salt = stark.randomAddress();

const sai = await loadSai();
sai.loadManifest();
await sai.declareClass("classic_arcade");

await sai.deployContract({
  tag: "classic_arcade",
  class: "classic_arcade",
  salt,
  unique: false,
  calldata: {
    owner: sai.account.address,
    attack_contract: sai.contracts["attack"].contract_address,
    loadout_contract: sai.contracts["arena_blobert_loadout"].contract_address,
  },
});
const contract = await sai.getContract("classic_arcade");
await sai.executeAndWait([
  contract.populate("grant_contract_writer", { writer: sai.account.address }),
  ...(await makeClassicArcadeCalls(sai)),
]);
sai.dumpJson();
