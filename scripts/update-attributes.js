import {
  loadJson,
  splitCallDescriptions,
  loadAccountManifestFromCmdArgs,
  makeCairoEnum,
  parseEnumObject,
  batchCalls,
} from "./stark-utils.js";
import { CairoCustomEnum } from "starknet";
import {
  seedEntrypoint,
  customEntrypoint,
  blobertContractTag,
  ammaBlobertContractTag,
  setFighterEntrypoint,
  setAmountOfFightersEntrypoint,
} from "./contract-defs.js";
import { pascalCase } from "pascal-case";

export const toSigned = (x) => {
  if (x >= 0) {
    return { sign: false, value: x };
  } else {
    return { sign: true, value: -x };
  }
};

export const parseNestedSignedStruct = (obj) => {
  for (let key in obj) {
    if (typeof obj[key] === "number") {
      obj[key] = toSigned(obj[key]);
    } else if (typeof obj[key] === "object" && obj[key] !== null) {
      parseNestedSignedStruct(obj[key]);
    }
  }
  return obj;
};

export const parseBlobertItemKey = (itemKey) => {
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

const makeAmmaFighterCallData = (n, fighter) => {
  return {
    fighter: Number(n),
    name: fighter.name,
    stats: fighter.stats,
    generated_stats: fighter.generated_stats,
    attacks: makeAttacksStruct(fighter.attacks),
  };
};

export const makeEffectStruct = (effect) => {
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

export const makeEffectsArray = (effects) => {
  let effectsArray = [];
  effects.forEach((effect) => {
    effectsArray.push(makeEffectStruct(effect));
  });
  return effectsArray;
};

export const makeRequirementsArray = (input) => {
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

export const parseNewAttack = (attack) => {
  return {
    name: attack.name,
    speed: attack.speed,
    accuracy: attack.accuracy,
    cooldown: attack.cooldown,
    hit: makeEffectsArray(attack.hit),
    miss: makeEffectsArray(attack.miss),
  };
};

export const makeAttacksStruct = (attacks) => {
  let attacksStructs = [];
  for (const attack of attacks) {
    attacksStructs.push(parseAttackStruct(attack));
  }
  return attacksStructs;
};

export const parseAttackStruct = (attack) => {
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

export const makeClassicBlobertSeedCalls = async (account_manifest) => {
  const seed_data = loadJson("./post-deploy-config/seed-attributes.json");
  let contract = await account_manifest.getContract(blobertContractTag);

  let calls = [];
  for (const [trait, traits] of Object.entries(seed_data)) {
    for (const [n, item] of Object.entries(traits)) {
      calls.push([
        contract.populate(seedEntrypoint, makeSeedItemCallData(trait, n, item)),
        { description: `seed: ${trait} ${n} ${item.name}` },
      ]);
    }
  }
  return calls;
};

export const makeClassicBlobertCustomCalls = async (account_manifest) => {
  const custom_data = loadJson("./post-deploy-config/custom-attributes.json");
  let contract = await account_manifest.getContract(blobertContractTag);

  let calls = [];
  for (const [n, item] of Object.entries(custom_data)) {
    calls.push([
      contract.populate(customEntrypoint, makeCustomItemCallData(n, item)),
      { description: `custom: ${n} ${item.name}` },
    ]);
  }
  return calls;
};

export const makeAmmaBlobertCalls = async (account_manifest) => {
  const amma_data = loadJson("./post-deploy-config/amma-attributes.json");
  let contract = await account_manifest.getContract(ammaBlobertContractTag);

  let calls = [];
  for (const [n, item] of Object.entries(amma_data)) {
    calls.push([
      contract.populate(setFighterEntrypoint, makeAmmaFighterCallData(n, item)),
      { description: `amma: ${n} ${item.name}` },
    ]);
  }
  calls.push([
    contract.populate(setAmountOfFightersEntrypoint, {
      amount: Object.keys(amma_data).length,
    }),
    { description: `amma: set_amount_of_fighters` },
  ]);
  return calls;
};

const main = async () => {
  const account_manifest = await loadAccountManifestFromCmdArgs();

  const calls_metas = [
    ...(await makeClassicBlobertSeedCalls(account_manifest)),
    ...(await makeClassicBlobertCustomCalls(account_manifest)),
    ...(await makeAmmaBlobertCalls(account_manifest)),
  ];
  for (const calls_metas_batch of batchCalls(calls_metas, 70)) {
    const [calls, descriptions] = splitCallDescriptions(calls_metas_batch);
    console.log(descriptions);
    const transaction_hash = await account_manifest.execute(calls);
    console.log(transaction_hash);
  }
};

if (process.argv[1] === import.meta.filename) {
  await main();
}
