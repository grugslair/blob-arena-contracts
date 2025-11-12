import { loadSai } from "./sai.js";
import { makeArenaBlobertCalls } from "./set-arena-token.js";
import { makeArcadeClassicCalls } from "./set-classic-arcade.js";
import { makeBlobertLoadouts } from "./set-classic-loadout.js";

const sai = await loadSai();
sai.loadManifest();

await sai.deployContract({
  tag: "amma_blobert_minter",
  class: "amma_blobert_minter",
  salt: null,
  unique: false,
  calldata: {
    token_address: sai.contracts["amma_blobert_soulbound"].contract_address,
  },
});
sai.dumpJson();
await sai.executeAndWait([
  (
    await sai.getContract("arena_blobert")
  ).populate("grant_contract_writer", {
    writer: sai.deployments["arena_blobert_minter"].contract_address,
  }),
  (
    await sai.getContract("amma_blobert_soulbound")
  ).populate("grant_contract_writer", {
    writer: sai.deployments["amma_blobert_minter"].contract_address,
  }),

  (
    await sai.getContract("action")
  ).populate("grant_contract_writers", {
    writers: [
      // sai.deployments["loadout_amma"].contract_address,
      sai.deployments["loadout_classic"].contract_address,
    ],
  }),
]);

await sai.executeAndWait(await makeBlobertLoadouts(sai));
await sai.executeAndWait([
  ...(await makeArenaBlobertCalls(sai)),
  ...(await makeArcadeClassicCalls(sai)),
]);

console.log("Granting writers and owners...");
await sai.executeAndWait([
  ...(await sai.grantOwnersCalls()),
  ...(await sai.grantWritersCalls()),
]);
