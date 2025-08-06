import { loadSai } from "./sai.js";
import { makeArenaBlobertCalls } from "./set-arena-token.js";
import { makeClassicArcadeCalls } from "./set-classic-arcade.js";
import { makeBlobertLoadouts } from "./set-classic-loadout.js";
import { stark } from "starknet";

const deployWithOwner = ["arena_blobert", "amma_blobert", "attack"];

const salt = stark.randomAddress();

const sai = await loadSai();
sai.loadManifest();
const owner = sai.account.address;

await sai.executeAndWait([
  ...(await Promise.all(
    ["arena_blobert_loadout", "classic_arcade"].map(async (name) =>
      (
        await sai.getContract(name)
      ).populate("grant_contract_writer", {
        writer: owner,
      })
    )
  )),
  (
    await sai.getContract("arena_blobert")
  ).populate("grant_contract_writer", {
    writer: sai.deployments["arena_blobert_minter"].contract_address,
  }),
  (
    await sai.getContract("attack")
  ).populate("grant_contract_writers", {
    writers: [
      // sai.deployments["amma_blobert_loadout"].contract_address,
      sai.deployments["arena_blobert_loadout"].contract_address,
    ],
  }),
]);

await sai.executeAndWait(await makeBlobertLoadouts(sai));
await sai.executeAndWait([
  ...(await makeClassicArcadeCalls(sai)),
  ...(await makeArenaBlobertCalls(sai)),
]);

console.log("Granting writers and owners...");
await sai.executeAndWait([
  ...(await sai.grantOwnersCalls()),
  ...(await sai.grantWritersCalls()),
]);
