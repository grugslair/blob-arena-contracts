import { loadSai } from "./sai.js";
import { makeArenaBlobertMinterCalls } from "./set-arena-blobert-minter.js";
import { makeArcadeClassicCalls } from "./set-arcade-classic.js";
import { makeLoadoutsClassic } from "./set-loadout-classic.js";
import { makeLoadoutsAmma } from "./set-loadout-amma.js";
import { config } from "starknet";
import { dumpToml, loadToml } from "./stark-utils.js";
import { makeArcadeAmmaCalls } from "./set-arcade-amma.js";
import { makeArenaCreditCalls } from "./set-arena-credits.js";
import { makePvpCalls } from "./set-pvp.js";
import {
  makeOrbPermissionsCalls,
  makeOrbsMinterConfigCalls,
  makeOrbTokenCalls,
} from "./set-orbs.js";
const deployWithOwner = [
  "arena_blobert",
  "amma_blobert",
  "amma_blobert_soulbound",
  "arena_credit",
  "orb",
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
    tag: "action",
    unique: false,
    calldata: {
      owner,
      action_model_class_hash: sai.classes.action_model.class_hash,
    },
  },
  {
    tag: "orb_minter",
    unique: false,
    calldata: {
      owner,
      token_address: sai.contracts.orb.contract_address,
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
      action_dispatcher_address: sai.contracts["action"].contract_address,
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
      action_dispatcher_address: sai.contracts["action"].contract_address,
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
      arcade_round_result_class_hash:
        sai.classes.arcade_round_result_model.class_hash,
      action_address: sai.contracts.action.contract_address,
      loadout_address: sai.contracts.loadout_classic.contract_address,
      orb_address: sai.contracts.orb.contract_address,
    },
  },
  {
    tag: "arcade_amma",
    unique: false,
    calldata: {
      owner,
      arcade_round_result_class_hash:
        sai.classes.arcade_round_result_model.class_hash,
      action_address: sai.contracts.action.contract_address,
      loadout_address: sai.contracts.loadout_amma.contract_address,
      orb_address: sai.contracts.orb.contract_address,
      collectable_address: sai.contracts.amma_blobert.contract_address,
    },
  },
  {
    tag: "pvp",
    unique: false,
    calldata: {
      owner,
      round_result_class_hash: sai.classes.round_result_model.class_hash,
      action_address: sai.contracts["action"].contract_address,
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
  ["action", "contract"],
  ["orb", "erc721"],
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
console.log("Contracts Deployed");
const writersCalls = await sai.setOnlyWritersCalls({
  arena_blobert: [sai.contracts.arena_blobert_minter.contract_address],
  amma_blobert_soulbound: [sai.contracts.amma_blobert_minter.contract_address],
  action: [
    owner,
    sai.contracts.loadout_amma.contract_address,
    sai.contracts.loadout_classic.contract_address,
    sai.contracts.arcade_classic.contract_address,
    sai.contracts.arcade_amma.contract_address,
  ],
  arena_credit: [
    sai.contracts.arcade_classic.contract_address,
    sai.contracts.arcade_amma.contract_address,
    sai.contracts.arena_credit_purchase.contract_address,
    sai.contracts.arena_blobert_minter.contract_address,
  ],
});

console.log("Setting writers...");
await sai.executeAndWait(writersCalls);

console.log("Setting classic loadouts...");
await sai.executeAndWait(await makeLoadoutsClassic(sai));

console.log("Setting amma loadouts...");
await sai.executeAndWait(await makeLoadoutsAmma(sai));

console.log("Setting arcade calls...");
await sai.executeAndWait([
  ...(await makeArenaBlobertMinterCalls(sai)),
  ...(await makeArcadeClassicCalls(sai)),
  ...(await makeArcadeAmmaCalls(sai)),
  ...(await makePvpCalls(sai)),
  ...(await makeArenaCreditCalls(sai)),
  ...(await makeOrbsMinterConfigCalls(sai)),
  ...(await makeOrbTokenCalls(sai)),
  ...(await makeOrbPermissionsCalls(sai)),
]);

console.log("Granting writers and owners...");
await sai.executeAndWait([
  ...(await sai.grantOwnersCalls()),
  ...(await sai.grantWritersCalls()),
]);
