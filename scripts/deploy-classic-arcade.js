import { loadSai } from "./sai.js";
import { makeArcadeClassicCalls } from "./set-classic-arcade.js";
import { stark } from "starknet";

const salt = stark.randomAddress();

const sai = await loadSai();
sai.loadManifest();
await sai.declareClass("arcade_classic");

await sai.deployContract({
  tag: "arcade_classic",
  class: "arcade_classic",
  salt,
  unique: false,
  calldata: {
    owner: sai.account.address,
    attack_contract: sai.contracts["attack"].contract_address,
    loadout_contract: sai.contracts["loadout_classic"].contract_address,
  },
});
const contract = await sai.getContract("arcade_classic");
await sai.executeAndWait([
  contract.populate("grant_contract_writer", { writer: sai.account.address }),
  ...(await makeArcadeClassicCalls(sai)),
]);
sai.dumpJson();
