import { loadSai } from "./sai.js";
import { makeArenaBlobertCalls } from "./set-arena-token.js";
import { makeArcadeClassicCalls } from "./set-arcade-classic.js";
import { makeLoadoutsClassic } from "./set-loadout-classic.js";
import { makeLoadoutsAmma } from "./set-loadout-amma.js";
import { stark, config } from "starknet";
import { dumpToml, loadToml } from "./stark-utils.js";
import { makeArcadeAmmaCalls } from "./set-arcade-amma.js";
import { makeArenaCreditCalls } from "./set-arena-credits.js";
const deployWithOwner = [
  "arena_blobert",
  "amma_blobert",
  "amma_blobert_soulbound",
  "arena_credit",
];

config.set("rpcVersion", "0.9.0");

const sai = await loadSai();
const owner = sai.account.address;

await sai.declareAllClasses();
await sai.deployAllContracts();
await sai.deployContract(
  deployWithOwner.map((tag) => ({
    tag,
    unique: false,
    calldata: { owner },
  }))
);
await sai.deployContract([
  {
    tag: "attack",
    unique: false,
    calldata: {
      owner,
      attack_model_class_hash: sai.classes.attack_model.class_hash,
    },
  },
  {
    tag: "arena_blobert_minter",
    unique: false,
    calldata: {
      owner,
      token_address: sai.contracts["arena_blobert"].contract_address,
    },
  },
  {
    tag: "amma_blobert_minter",
    unique: false,
    calldata: {
      token_address: sai.contracts["amma_blobert_soulbound"].contract_address,
    },
  },
  {
    tag: "arena_credit_purchase",
    unique: false,
    calldata: {
      owner,
      credit_address: sai.contracts["arena_credit"].contract_address,
    },
  },
]);
await sai.deployContract([
  {
    tag: "loadout_classic",
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
    unique: false,
    calldata: {
      owner,
      attack_address: sai.contracts["attack"].contract_address,
      loadout_address: sai.contracts["loadout_classic"].contract_address,
      credit_address: sai.contracts["arena_credit"].contract_address,
      vrf_address: sai.contracts["vrf"].contract_address,
    },
  },
  {
    tag: "arcade_amma",
    unique: false,
    calldata: {
      owner,
      attack_address: sai.contracts["attack"].contract_address,
      loadout_address: sai.contracts["loadout_amma"].contract_address,
      credit_address: sai.contracts["arena_credit"].contract_address,
      vrf_address: sai.contracts["vrf"].contract_address,
      collectable_address: sai.contracts["amma_blobert"].contract_address,
    },
  },
  {
    tag: "pvp",
    unique: false,
    calldata: {
      attack_address: sai.contracts["attack"].contract_address,
    },
  },
]);

sai.dumpManifest();

const toriiContract = [
  ["arena_blobert", "erc721"],
  ["amma_blobert", "erc721"],
  ["amma_blobert_soulbound", "erc721"],
  ["arena_blobert_minter", "contract"],
  ["amma_blobert_minter", "contract"],
  ["loadout_classic", "contract"],
  ["loadout_amma", "contract"],
  ["attack", "contract"],
  ["arcade_classic", "contract"],
  ["arcade_amma", "contract"],
  ["arena_credit", "contract"],
  ["pvp", "contract"],
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
    writer: sai.contracts["arena_blobert_minter"].contract_address,
  }),
  (
    await sai.getContract("amma_blobert_soulbound")
  ).populate("grant_contract_writer", {
    writer: sai.contracts["amma_blobert_minter"].contract_address,
  }),

  (
    await sai.getContract("attack")
  ).populate("grant_contract_writers", {
    writers: [
      sai.contracts["loadout_amma"].contract_address,
      sai.contracts["loadout_classic"].contract_address,
      sai.contracts["arcade_classic"].contract_address,
      sai.contracts["arcade_amma"].contract_address,
    ],
  }),
  (
    await sai.getContract("arena_credit")
  ).populate("grant_contract_writers", {
    writers: [
      sai.contracts["arcade_classic"].contract_address,
      sai.contracts["arcade_amma"].contract_address,
      sai.contracts["arena_credit_purchase"].contract_address,
    ],
  }),
]);

console.log("Setting classic loadouts...");
await sai.executeAndWait(await makeLoadoutsClassic(sai));

console.log("Setting amma loadouts...");
await sai.executeAndWait(await makeLoadoutsAmma(sai));

console.log("Setting arcade calls...");
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
