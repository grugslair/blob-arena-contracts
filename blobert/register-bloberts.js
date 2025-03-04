import {
  RpcProvider,
  Account,
  CallData,
  byteArray,
  CairoCustomEnum,
  Contract,
} from "starknet";

import * as fs from "fs";
import * as path from "path";
import { fileURLToPath } from "url";
import { dirname } from "path";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const loadJson = (rpath) => {
  return JSON.parse(fs.readFileSync(path.resolve(__dirname, rpath)));
};

const getContractAddress = (mainfest, contractName) => {
  for (const contract of mainfest.contracts) {
    if (contract.tag === contractName) {
      return contract.address;
    }
  }
  return null;
};

const getContract = async (provider, contractAddress) => {
  console.log(contractAddress);
  const { abi: abi } = await provider.getClassAt(contractAddress);
  return new Contract(abi, contractAddress, provider);
};

const profile = process.argv[2];

const seed_data = loadJson("./seed-attributes.json");
const custom_data = loadJson("./custom-attributes.json");
const amma_data = loadJson("./amma-attributes.json");
const pve_data = loadJson("./pve.json");
const role_data = loadJson("./roles.json")[profile];
const manifest = loadJson(`../manifest_${profile}.json`);

const blobertContractTag = "blobert-blobert_actions";
const arcadeBlobertContractTag = "arcade_blobert-arcade_blobert_actions";
const ammaBlobertContractTag = "amma_blobert-amma_blobert_actions";
const pveBlobertContractTag = "pve_blobert-pve_blobert_admin_actions";
const gameAdminContractTag = "blob_arena-game_admin";

const seedEntrypoint = "set_seed_item_with_attacks";
const customEntrypoint = "set_custom_item_with_attacks";
const pveOpponentEntrypoint = "new_opponent";
const pveChallengeEntrypoint = "new_challenge";
const setPermissionsEntrypoint = "set_multiple_has_role";

const provider = new RpcProvider({ nodeUrl: process.env.STARKNET_RPC_URL });
const account1Address = process.env.DOJO_ACCOUNT_ADDRESS;
const privateKey1 = process.env.DOJO_PRIVATE_KEY;
const account = new Account(provider, account1Address, privateKey1);

const blobertContractAddress = getContractAddress(manifest, blobertContractTag);
const arcadeContractAddress = getContractAddress(
  manifest,
  arcadeBlobertContractTag
);
const ammaBlobertContractAddress = getContractAddress(
  manifest,
  ammaBlobertContractTag
);
const pveBlobertContractAddress = getContractAddress(
  manifest,
  pveBlobertContractTag
);
const gameAdminContractAddress = getContractAddress(
  manifest,
  gameAdminContractTag
);

const blobertContract = await getContract(provider, blobertContractAddress);
const ammaBlobertContract = await getContract(
  provider,
  ammaBlobertContractAddress
);
const pveBlobertContract = await getContract(
  provider,
  pveBlobertContractAddress
);
const gameAdminContract = await getContract(provider, gameAdminContractAddress);

const PVECollectionAddresses = {
  blobert: blobertContractAddress,
  arcade_blobert: arcadeContractAddress,
  amma_blobert: ammaBlobertContractAddress,
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

const parseNewAttack = (attack) => {
  return {
    name: attack.name,
    speed: attack.speed,
    accuracy: attack.accuracy,
    cooldown: attack.cooldown,
    hit: makeEffectsArray(attack.hit),
    miss: makeEffectsArray(attack.miss),
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

const parseNewPVEOpponent = (opponent) => {
  return {
    name: opponent.name,
    collection: PVECollectionAddresses[opponent.collection],
    attributes: new CairoCustomEnum(opponent.attributes),
    stats: opponent.stats,
    attacks: makeAttacksStruct(opponent.attacks),
    collections_allowed: makeCollectionsAllowed(opponent.collections_allowed),
  };
};

const makePveOpponentsStruct = (opponents) => {
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
  return new CairoCustomEnum({ New: parseNewPVEOpponent(opponent) });
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
    allowed.push(PVECollectionAddresses[collection]);
  }
  return allowed;
};

const makePveChallengeCallData = (challenge) => {
  return {
    name: challenge.name,
    health_recovery_pc: challenge.health_recovery,
    opponents: makePveOpponentsStruct(challenge.opponents),
    collections_allowed: makeCollectionsAllowed(challenge.collections_allowed),
  };
};

const makeCall = (contract, entrypoint, calldata) => {
  return contract.populate(entrypoint, calldata);
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

for (const opponent of pve_data["opponents"]) {
  calls.push([
    `pve: ${opponent.name}`,
    makeCall(
      pveBlobertContract,
      pveOpponentEntrypoint,
      parseNewPVEOpponent(opponent)
    ),
  ]);
}
for (const challenge of pve_data["challenges"]) {
  calls.push([
    `pve: ${challenge.name}`,
    makeCall(
      pveBlobertContract,
      pveChallengeEntrypoint,
      makePveChallengeCallData(challenge)
    ),
  ]);
}
const multiCallSize = 70;
for (let i = 0, x = 0; i < calls.length; i += multiCallSize, x += 1) {
  const chunk = calls.slice(i, i + multiCallSize);
  const names = chunk.map(([name, call]) => name);
  const multicall = chunk.map(([name, call]) => call);
  console.log(names);
  const transaction = await account.execute(multicall);
  const response = await provider.waitForTransaction(
    transaction.transaction_hash
  );
  console.log(response.transaction_hash);
}
