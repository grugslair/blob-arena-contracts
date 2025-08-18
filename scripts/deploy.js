import { loadSai } from "./sai.js";
import { makeArenaBlobertCalls } from "./set-arena-token.js";
import { makeClassicArcadeCalls } from "./set-classic-arcade.js";
import { makeBlobertLoadouts } from "./set-classic-loadout.js";
import { stark } from "starknet";
import { dumpToml, loadToml } from "./stark-utils.js";

const deployWithOwner = ["arena_blobert", "amma_blobert", "attack"];

const salt = stark.randomAddress();

const sai = await loadSai();
const owner = sai.account.address;

await sai.declareAllClasses();
await sai.deployContract(
  deployWithOwner.map((name) => ({
    tag: name,
    class: name,
    salt,
    unique: false,
    calldata: { owner },
  }))
);

await sai.deployContract([
  {
    tag: "arena_blobert_minter",
    class: "arena_blobert_minter",
    salt,
    unique: false,
    calldata: {
      owner,
      token_address: sai.contracts["arena_blobert"].contract_address,
    },
  },
  {
    tag: "amma_blobert_soulbound",
    class: "amma_blobert_soulbound",
    salt,
    unique: false,
    calldata: {
      owner,
      collectable_address: sai.contracts["amma_blobert"].contract_address,
    },
  },
  {
    tag: "arena_blobert_loadout",
    class: "arena_blobert_loadout",
    salt,
    unique: false,
    calldata: {
      owner,
      attack_dispatcher_address: sai.contracts["attack"].contract_address,
      collection_addresses: [
        sai.contracts["arena_blobert"].contract_address,
        sai.contracts["blobert"].contract_address,
      ],
    },
  },
]);

await sai.deployContract([
  {
    tag: "amma_blobert_minter",
    class: "amma_blobert_minter",
    salt,
    unique: false,
    calldata: {
      token_address: sai.contracts["amma_blobert_soulbound"].contract_address,
    },
  },
  {
    tag: "classic_arcade",
    class: "classic_arcade",
    salt,
    unique: false,
    calldata: {
      owner,
      attack_contract: sai.contracts["attack"].contract_address,
      loadout_contract: sai.contracts["arena_blobert_loadout"].contract_address,
    },
  },
]);

sai.dumpManifest();
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
  ...(await makeArenaBlobertCalls(sai)),
  ...(await makeClassicArcadeCalls(sai)),
]);

console.log("Granting writers and owners...");
await sai.executeAndWait([
  ...(await sai.grantOwnersCalls()),
  ...(await sai.grantWritersCalls()),
]);

const toriiContract = [
  ["arena_blobert", "erc721-world"],
  ["amma_blobert", "erc721-world"],
  ["amma_blobert_soulbound", "erc721-world"],
  ["arena_blobert_minter", "contract"],
  ["amma_blobert_minter", "contract"],
  ["arena_blobert_loadout", "contract"],
  ["attack", "contract"],
  ["classic_arcade", "contract"],
  ["amma_arcade", "contract"],
]
  .filter(([tag]) => sai.contracts[tag])
  .map(([tag, type]) => `${type}:${sai.contracts[tag].contract_address}`);
const toriiConfigPath = `torii_${sai.profile}.toml`;

const torii = loadToml(toriiConfigPath);
torii.indexing.contracts = toriiContract;
dumpToml(torii, toriiConfigPath);
