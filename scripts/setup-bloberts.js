#!/usr/bin/env node

import { Account, CairoCustomEnum, Contract } from "starknet";
import { upperFirst, camelCase } from "lodash-es";
import * as fs from "fs";
import * as path from "path";
import { fileURLToPath } from "url";
import { dirname } from "path";
import commandLineArgs from "command-line-args";
import * as accounts from "web3-eth-accounts";
import * as toml from "toml";

const pascalCase = (str) => {
  return upperFirst(camelCase(str));
};

const loadJson = (path) => {
  return JSON.parse(fs.readFileSync(resolvePath(path)));
};

const loadToml = (path) => {
  return toml.parse(fs.readFileSync(resolvePath(path)));
};

const resolvePath = (rpath) => {
  return path.resolve(__dirname, rpath);
};

const getContractAddress = (mainfest, contractName) => {
  for (const contract of mainfest.contracts) {
    if (contract.tag === contractName) {
      return contract.address;
    }
  }
  return null;
};

const readKeystorePK = async (keystorePath, accountAddress, password) => {
  let data = loadJson(keystorePath);
  data.address = accountAddress;
  return (await accounts.decrypt(data, password)).privateKey;
};

const getContract = async (provider, contractAddress) => {
  console.log(contractAddress);
  const { abi: abi } = await provider.getClassAt(contractAddress);
  return new Contract(abi, contractAddress, provider);
};

const toSigned = (x) => {
  if (x >= 0) {
    return { sign: false, value: x };
  } else {
    return { sign: true, value: -x };
  }
};

function parseNestedSignedStruct(obj) {
  for (let key in obj) {
    if (typeof obj[key] === "number") {
      obj[key] = toSigned(obj[key]);
    } else if (typeof obj[key] === "object" && obj[key] !== null) {
      parseNestedSignedStruct(obj[key]);
    }
  }
  return obj;
}

const makeCairoEnum = (option) => {
  let [key, value] = parseEnumObject(option);
  return new CairoCustomEnum({ [key]: value });
};

const parseEnumObject = (obj) => {
  if (["string"].includes(typeof obj)) {
    return [obj, {}];
  } else {
    for (const o in obj) {
      return [o, obj[o]];
    }
  }
};

const parseBlobertItemKey = (itemKey) => {
  const [key, value] = Object.entries(itemKey)[0];
  if (key == "Seed") {
    return new CairoCustomEnum({
      Seed: {
        attribute: new CairoCustomEnum({ [value.attribute]: {} }),
        attribute_id: value.attribute_id,
      },
    });
  }
  if (key == "Custom") {
    return new CairoCustomEnum({ Custom: value });
  }
};

const makeEffectStruct = (effect) => {
  let [key, affect] = parseEnumObject(effect.affect);

  if (key == "Stat") {
    effect.affect.Stat = parseNestedSignedStruct(makeCairoEnum(value.stats));
  } else if (["Health", "Stats"].includes(key)) {
    effect.affect = parseNestedSignedStruct(effect.affect);
  } else if (key == "Stats") {
    effect.affect = parseNestedSignedStruct(effect.affect);
  }
  return {
    target: makeCairoEnum(effect.target),
    affect: makeCairoEnum(effect.affect),
  };
};

const makeEffectsArray = (effects) => {
  let effectsArray = [];
  effects.forEach((effect) => {
    effectsArray.push(makeEffectStruct(effect));
  });
  return effectsArray;
};

const makeRequirementsArray = (input) => {
  let requirements = [];
  if (input) {
    for (const requirement of input) {
      const [key, value] = Object.entries(requirement)[0];
      requirements.push(
        new CairoCustomEnum({ [pascalCase(key)]: Number(value) })
      );
    }
  }
  return requirements;
};

const parseNewAttack = (attack) => {
  return {
    name: attack.name,
    speed: attack.speed,
    accuracy: attack.accuracy,
    cooldown: attack.cooldown,
    hit: makeEffectsArray(attack.hit),
    miss: makeEffectsArray(attack.miss),
    requirements: makeRequirementsArray(attack.requirements),
  };
};

const makeAttacksStruct = (attacks) => {
  let attacksStructs = [];
  for (const attack of attacks) {
    attacksStructs.push(parseAttackStruct(attack));
  }
  return attacksStructs;
};

const parseAttackStruct = (attack) => {
  if (typeof attack.tag === "string") {
    return new CairoCustomEnum({ Tag: attack.tag });
  }
  if (attack.id != null) {
    return new CairoCustomEnum({ Id: attack.id });
  }
  if (attack.new != null) {
    return new CairoCustomEnum({ New: attack.new });
  }
  return new CairoCustomEnum({ New: parseNewAttack(attack) });
};

const parseNewArcadeOpponent = (opponent) => {
  return {
    name: opponent.name,
    collection: ArcadeCollectionAddresses[opponent.collection],
    attributes: new CairoCustomEnum(opponent.attributes),
    stats: opponent.stats,
    attacks: makeAttacksStruct(opponent.attacks),
    collections_allowed: makeCollectionsAllowed(opponent.collections_allowed),
  };
};

const makeArcadeOpponentsStruct = (opponents) => {
  let opponentsStructs = [];
  for (const opponent of opponents) {
    opponentsStructs.push(parseOpponentStruct(opponent));
  }
  return opponentsStructs;
};

const parseOpponentStruct = (opponent) => {
  if (typeof opponent.tag === "string") {
    return new CairoCustomEnum({ Tag: opponent.tag });
  }
  if (opponent.id != null) {
    return new CairoCustomEnum({ Id: opponent.id });
  }
  if (opponent.new != null) {
    return new CairoCustomEnum({ New: opponent.new });
  }
  return new CairoCustomEnum({ New: parseNewArcadeOpponent(opponent) });
};

const makeSeedItemCallData = (trait, n, item) => {
  const trait_str = trait.charAt(0).toUpperCase() + trait.slice(1);
  return {
    attribute: makeCairoEnum(trait_str),
    id: Number(n),
    name: item.name,
    stats: item.stats,
    attacks: makeAttacksStruct(item.attacks),
  };
};

const makeCustomItemCallData = (n, item) => {
  return {
    id: Number(n),
    name: item.name,
    stats: item.stats,
    attacks: makeAttacksStruct(item.attacks),
  };
};

const makeAttackSlots = (attack_slots) => {
  let slots = [];
  for (const [item, slot] of attack_slots) {
    slots.push([parseBlobertItemKey(item), slot]);
  }
  return slots;
};

const makeCollectionsAllowed = (collections) => {
  let allowed = [];
  for (const collection of collections) {
    allowed.push(ArcadeCollectionAddresses[collection]);
  }
  return allowed;
};

const makeArcadeChallengeCallData = (challenge) => {
  return {
    name: challenge.name,
    health_recovery_pc: challenge.health_recovery,
    opponents: makeArcadeOpponentsStruct(challenge.opponents),
    collections_allowed: makeCollectionsAllowed(challenge.collections_allowed),
  };
};

const makeCall = (contract, entrypoint, calldata) => {
  return contract.populate(entrypoint, calldata);
};

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const optionDefinitions = [
  { name: "profile", type: String, defaultOption: true },
  { name: "password", alias: "p", type: String },
];

const options = commandLineArgs(optionDefinitions);
const profile = options.profile;

const seed_data = loadJson("./seed-attributes.json");
const custom_data = loadJson("./custom-attributes.json");
const amma_data = loadJson("./amma-attributes.json");
const arcade_data = loadJson("./arcade-mode.json");
const role_data = loadJson("./roles.json")[profile];
const manifest = loadJson(`../manifest_${profile}.json`);
const dojo_toml = loadToml(`../dojo_${profile}.toml`);

const rpcUrl = dojo_toml.env.rpc_url;
const accountAddress = dojo_toml.env.account_address;
const keystorePath = resolvePath(dojo_toml.env.keystore_path);

const privateKey = await readKeystorePK(
  keystorePath,
  accountAddress,
  options.password
);

const account = new Account({ nodeUrl: rpcUrl }, accountAddress, privateKey);

const blobertContractTag = "blobert-blobert_actions";
const freeBlobertContractTag = "free_blobert-free_blobert_actions";
const ammaBlobertContractTag = "amma_blobert-amma_blobert_actions";
const arcadeBlobertContractTag = "arcade_blobert-arcade_blobert_admin_actions";
const gameAdminContractTag = "blob_arena-game_admin";

const seedEntrypoint = "set_seed_item_with_attacks";
const customEntrypoint = "set_custom_item_with_attacks";
const arcadeOpponentEntrypoint = "new_opponent";
const arcadeChallengeEntrypoint = "new_challenge";
const setPermissionsEntrypoint = "set_multiple_has_role";

const blobertContractAddress = getContractAddress(manifest, blobertContractTag);
const freeBlobertContractAddress = getContractAddress(
  manifest,
  freeBlobertContractTag
);
const ammaBlobertContractAddress = getContractAddress(
  manifest,
  ammaBlobertContractTag
);
const arcadeBlobertContractAddress = getContractAddress(
  manifest,
  arcadeBlobertContractTag
);
const gameAdminContractAddress = getContractAddress(
  manifest,
  gameAdminContractTag
);

const blobertContract = await getContract(account, blobertContractAddress);
const ammaBlobertContract = await getContract(
  account,
  ammaBlobertContractAddress
);
const arcadeBlobertContract = await getContract(
  account,
  arcadeBlobertContractAddress
);
const gameAdminContract = await getContract(account, gameAdminContractAddress);

const ArcadeCollectionAddresses = {
  blobert: blobertContractAddress,
  free_blobert: freeBlobertContractAddress,
  amma_blobert: ammaBlobertContractAddress,
};

let calls = [];
for (const [role, users] of Object.entries(role_data)) {
  calls.push([
    `role: ${role}`,
    makeCall(gameAdminContract, setPermissionsEntrypoint, {
      users,
      role: new CairoCustomEnum({ [role]: {} }),
      has: true,
    }),
  ]);
}

for (const [trait, traits] of Object.entries(seed_data)) {
  for (const [n, item] of Object.entries(traits)) {
    calls.push([
      `seed: ${trait} ${n} ${item.name}`,
      makeCall(
        blobertContract,
        seedEntrypoint,
        makeSeedItemCallData(trait, n, item)
      ),
    ]);
  }
}

for (const [n, item] of Object.entries(custom_data)) {
  calls.push([
    `custom: ${n} ${item.name}`,
    makeCall(
      blobertContract,
      customEntrypoint,
      makeCustomItemCallData(trait, n, item)
    ),
  ]);
}
for (const [n, item] of Object.entries(amma_data)) {
  calls.push([
    `amma: ${n} ${item.name}`,
    makeCall(
      ammaBlobertContract,
      customEntrypoint,
      makeCustomItemCallData(n, item)
    ),
  ]);
}

for (const opponent of arcade_data["opponents"]) {
  calls.push([
    `arcade: ${opponent.name}`,
    makeCall(
      arcadeBlobertContract,
      arcadeOpponentEntrypoint,
      parseNewArcadeOpponent(opponent)
    ),
  ]);
}
for (const challenge of arcade_data["challenges"]) {
  calls.push([
    `arcade: ${challenge.name}`,
    makeCall(
      arcadeBlobertContract,
      arcadeChallengeEntrypoint,
      makeArcadeChallengeCallData(challenge)
    ),
  ]);
}
// const multiCallSize = 70;
// for (let i = 0, x = 0; i < calls.length; i += multiCallSize, x += 1) {
//   const chunk = calls.slice(i, i + multiCallSize);
//   const names = chunk.map(([name, call]) => name);
//   const multicall = chunk.map(([name, call]) => call);
//   console.log(names);
//   const transaction = await account.execute(multicall);
//   const response = await provider.waitForTransaction(
//     transaction.transaction_hash
//   );
//   console.log(response.transaction_hash);
// }
