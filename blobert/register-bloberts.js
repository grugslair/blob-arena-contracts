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

const seed_data = loadJson("./seed-attributes.json");
const custom_data = loadJson("./custom-attributes.json");
const amma_data = loadJson("./amma-attributes.json");
const manifest = loadJson(`../manifest_${process.argv[2]}.json`);

const blobertContractTag = "blobert-blobert_actions";
const ammaBlobertContractTag = "amma_blobert-amma_blobert_actions";
const seedEntrypoint = "set_seed_item_with_attacks";
const customEntrypoint = "set_custom_item_with_attacks";

const amma_offset = 50;

const provider = new RpcProvider({ nodeUrl: process.env.STARKNET_RPC_URL });
const account1Address = process.env.DOJO_ACCOUNT_ADDRESS;
const privateKey1 = process.env.DOJO_PRIVATE_KEY;
const account = new Account(provider, account1Address, privateKey1);

const blobertContract = await getContract(
  provider,
  getContractAddress(manifest, blobertContractTag)
);
const ammaBlobertContract = await getContract(
  provider,
  getContractAddress(manifest, ammaBlobertContractTag)
);

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

const makeAttacksStruct = (attacks) => {
  let attacksStructs = [];
  for (const attack of attacks) {
    attacksStructs.push({
      name: attack.name,
      speed: attack.speed,
      accuracy: attack.accuracy,
      cooldown: attack.cooldown,
      hit: makeEffectsArray(attack.hit),
      miss: makeEffectsArray(attack.miss),
    });
  }
  return attacksStructs;
};

const makeSeedItemCallData = (trait, n, item) => {
  const trait_str = trait.charAt(0).toUpperCase() + trait.slice(1);
  return {
    attribute: makeCairoEnum(trait_str),
    attribute_id: Number(n),
    item_name: item.name,
    stats: item.stats,
    attacks: makeAttacksStruct(item.attacks),
  };
};

const makeCustomItemCallData = (n, item) => {
  return {
    custom_id: Number(n),
    item_name: item.name,
    stats: item.stats,
    attacks: makeAttacksStruct(item.attacks),
  };
};

const makeCall = (contract, entrypoint, calldata) => {
  return contract.populate(entrypoint, calldata);
};

let calls = [];
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

const multiCallSize = 20;
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
