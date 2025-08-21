import { loadSai } from "./sai.js";
import { makeArenaBlobertCalls } from "./set-arena-token.js";
import { makeArcadeClassicCalls } from "./set-arcade-classic.js";
import { makeLoadoutsClassic } from "./set-loadout-classic.js";
import { makeLoadoutsAmma } from "./set-loadout-amma.js";
import { stark } from "starknet";
import { dumpToml, loadToml } from "./stark-utils.js";
import { makeArcadeAmmaCalls } from "./set-arcade-amma.js";
import { makeArenaCreditCalls } from "./set-arena-credits.js";

const deployWithOwner = [
  "arena_blobert",
  "amma_blobert",
  "amma_blobert_soulbound",
  "attack",
  "arena_credit",
];

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
    tag: "amma_blobert_minter",
    class: "amma_blobert_minter",
    salt,
    unique: false,
    calldata: {
      token_address: sai.contracts["amma_blobert_soulbound"].contract_address,
    },
  },
  {
    tag: "loadout_classic",
    class: "loadout_classic",
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
  {
    tag: "loadout_amma",
    class: "loadout_amma",
    salt,
    unique: false,
    calldata: {
      owner,
      attack_dispatcher_address: sai.contracts["attack"].contract_address,
      collection_addresses: [
        sai.contracts["amma_blobert"].contract_address,
        sai.contracts["amma_blobert_soulbound"].contract_address,
      ],
    },
  },
]);

await sai.deployContract([
  {
    tag: "arcade_classic",
    class: "arcade_classic",
    salt,
    unique: false,
    calldata: {
      owner,
      attack_address: sai.contracts["attack"].contract_address,
      loadout_address: sai.contracts["loadout_classic"].contract_address,
      credit_address: sai.contracts["arena_credit"].contract_address,
    },
  },
  {
    tag: "arcade_amma",
    class: "arcade_amma",
    salt,
    unique: false,
    calldata: {
      owner,
      attack_address: sai.contracts["attack"].contract_address,
      loadout_address: sai.contracts["loadout_amma"].contract_address,
      credit_address: sai.contracts["arena_credit"].contract_address,
      collectable_address: sai.contracts["amma_blobert"].contract_address,
    },
  },
]);

sai.dumpManifest();

const toriiContract = [
  ["arena_blobert", "erc721-world"],
  ["amma_blobert", "erc721-world"],
  ["amma_blobert_soulbound", "erc721-world"],
  ["arena_blobert_minter", "contract"],
  ["amma_blobert_minter", "contract"],
  ["loadout_classic", "contract"],
  ["loadout_amma", "contract"],
  ["attack", "contract"],
  ["arcade_classic", "contract"],
  ["arcade_amma", "contract"],
  ["arena_credit", "contract"],
]
  .filter(([tag]) => sai.contracts[tag])
  .map(([tag, type]) => `${type}:${sai.contracts[tag].contract_address}`);
const toriiConfigPath = `torii_${sai.profile}.toml`;

const torii = loadToml(toriiConfigPath);
torii.indexing.contracts = toriiContract;
dumpToml(torii, toriiConfigPath);

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
      sai.deployments["loadout_amma"].contract_address,
      sai.deployments["loadout_classic"].contract_address,
    ],
  }),
  (
    await sai.getContract("arena_credit")
  ).populate("grant_contract_writers", {
    writers: [
      sai.deployments["arcade_classic"].contract_address,
      sai.deployments["arcade_amma"].contract_address,
    ],
  }),
]);

console.log("Setting classic loadouts...");
await sai.executeAndWait(await makeLoadoutsClassic(sai));

console.log("Setting amma loadouts...");
await sai.executeAndWait(await makeLoadoutsAmma(sai));

console.log("Setting arena blobert minter...");
await sai.executeAndWait([
  ...(await makeArenaBlobertCalls(sai)),
  ...(await makeArcadeClassicCalls(sai)),
  ...(await makeArcadeAmmaCalls(sai)),
  ...(await makeArenaCreditCalls(sai)),
]);

console.log("Granting writers and owners...");
await sai.executeAndWait([
  ...(await sai.grantOwnersCalls()),
  ...(await sai.grantWritersCalls()),
]);
