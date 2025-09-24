import { makeCairoEnum, parseEnumObject } from "./stark-utils.js";
import { CairoCustomEnum } from "starknet";
import pkg from "case";
const { pascal } = pkg;

const B100ToN100Affects = [
  "Strength",
  "Vitality",
  "Dexterity",
  "Luck",
  "BludgeonResistance",
  "MagicResistance",
  "PierceResistance",
  "Health",
];

const I16Affects = [
  "BludgeonVulnerability",
  "MagicVulnerability",
  "PierceVulnerability",
];

const LE100Affects = ["Stun", "Block"];

const parseDamageType = (damageType) => {
  return makeCairoEnum(damageType, "None");
};

const parseDamage = (damage) => {
  return {
    power: parse1To100(damage.power, "Power"),
    critical: parse0To100(damage.critical, "Critical"),
    damage_type: parseDamageType(damage.damage_type),
  };
};

const parseAffectStruct = (affectInput) => {
  let [key, affect] = parseEnumObject(affectInput);
  key = pascal(key);

  if (B100ToN100Affects.includes(key)) {
    affect = { [key]: parseN100To100Ne0(affect, key) };
  } else if (I16Affects.includes(key)) {
    affect = { [key]: parseI16Ne0(affect, key) };
  } else if (key === "Damage") {
    affect = { Damage: parseDamage(affect) };
  } else if (LE100Affects.includes(key)) {
    affect = { [key]: parse1To100(affect, key) };
  } else if (key === "Abilities") {
    affect = { Abilities: parseAbilityMods(affect) };
  } else if (key === "Resistances") {
    affect = { Resistances: parseResistanceMods(affect) };
  } else if (key === "Vulnerabilities") {
    affect = { Vulnerabilities: parseVulnerabilityMods(affect) };
  } else {
    throw new Error(`Unknown effect affect: ${key}`);
  }
  return new CairoCustomEnum({ [key]: affect[key] });
};
const makeEffect = (target, affect) => ({
  target: parseTarget(target),
  affect: parseAffectStruct(affect),
});

// const parseEffectStruct = (effect) => {
//   let target = parseTarget(effect.target);
//   return Object.entries(effect)
//     .filter(([k, v]) => k.toLowerCase() !== "target")
//     .flatMap(([k, v]) => {
//       if (k === "affect") {
//         return makeEffect(target, v);
//       }
//       if (k === "affects") {
//         if (Array.isArray(v)) {
//           return v.map((affect) => makeEffect(target, affect));
//         }
//         return Object.entries(v).map(([k, v]) =>
//           makeEffect(target, { [k]: v })
//         );
//       }
//       return makeEffect(target, { [k]: v });
//     });
// };

const parseEffects = (target, affects) => {
  if (typeof affects === "object") {
    if ("affects" in affects) {
      return parseEffects(target, affects.affects);
    }
    if ("affect" in affects) {
      return makeEffect(target, affects.affect);
    }
    return Object.entries(affects)
      .filter(([k, _]) => k.toLowerCase() !== "target")
      .flatMap(([k, v]) => makeEffect(target, { [k]: v }));
  }
  if (Array.isArray(affects)) {
    return affects.flatMap((affect) => makeEffect(target, affect));
  }
};

const parseTarget = (target) => {
  let [key, _] = parseEnumObject(target);
  key = pascal(key);
  if (key === "Attacker" || key === "Defender") {
    return new CairoCustomEnum({ [key]: {} });
  }
  throw new Error(`Unknown effect target: ${key}`);
};

const parseEffectsArray = (effects) => {
  if (Array.isArray(effects)) {
    return effects.flatMap((effect) => parseEffects(effect.target, effect));
  }
  return Object.entries(effects).flatMap(([k, v]) => parseEffects(k, v));
};

export const parseAttributes = (attributes) => {
  return {
    strength: parse0To100(attributes.strength, "Strength"),
    vitality: parse0To100(attributes.vitality, "Vitality"),
    dexterity: parse0To100(attributes.dexterity, "Dexterity"),
    luck: parse0To100(attributes.luck, "Luck"),
    bludgeon_resistance: parse0To100(
      attributes.bludgeon_resistance,
      "Bludgeon Resistance"
    ),
    magic_resistance: parse0To100(
      attributes.magic_resistance,
      "Magic Resistance"
    ),
    pierce_resistance: parse0To100(
      attributes.pierce_resistance,
      "Pierce Resistance"
    ),
    bludgeon_vulnerability: parseU16(
      attributes.bludgeon_vulnerability,
      "Bludgeon Vulnerability"
    ),
    magic_vulnerability: parseU16(
      attributes.magic_vulnerability,
      "Magic Vulnerability"
    ),
    pierce_vulnerability: parseU16(
      attributes.pierce_vulnerability,
      "Pierce Vulnerability"
    ),
  };
};

export const parsePartialAttributes = (attributes) => {
  return {
    strength: parseI8(attributes.strength, "Strength"),
    vitality: parseI8(attributes.vitality, "Vitality"),
    dexterity: parseI8(attributes.dexterity, "Dexterity"),
    luck: parseI8(attributes.luck, "Luck"),
    bludgeon_resistance: parse0To100(
      attributes.bludgeon_resistance,
      "Bludgeon Resistance"
    ),
    magic_resistance: parse0To100(
      attributes.magic_resistance,
      "Magic Resistance"
    ),
    pierce_resistance: parse0To100(
      attributes.pierce_resistance,
      "Pierce Resistance"
    ),
    bludgeon_vulnerability: parseI16(
      attributes.bludgeon_vulnerability,
      "Bludgeon Vulnerability"
    ),
    magic_vulnerability: parseI16(
      attributes.magic_vulnerability,
      "Magic Vulnerability"
    ),
    pierce_vulnerability: parseI16(
      attributes.pierce_vulnerability,
      "Pierce Vulnerability"
    ),
  };
};

export const parseAbilityMods = (abilityMods) => {
  return {
    strength: parseN100To100(abilityMods.strength, "Strength"),
    vitality: parseN100To100(abilityMods.vitality, "Vitality"),
    dexterity: parseN100To100(abilityMods.dexterity, "Dexterity"),
    luck: parseN100To100(abilityMods.luck, "Luck"),
  };
};

export const parseResistanceMods = (resistances) => {
  return {
    bludgeon_resistance: parseN100To100(
      resistances.bludgeon_resistance,
      "Bludgeon Resistance"
    ),
    magic_resistance: parseN100To100(
      resistances.magic_resistance,
      "Magic Resistance"
    ),
    pierce_resistance: parseN100To100(
      resistances.pierce_resistance,
      "Pierce Resistance"
    ),
  };
};

export const parseVulnerabilityMods = (vulnerabilities) => {
  return {
    bludgeon_vulnerability: parseI16(
      vulnerabilities.bludgeon_vulnerability,
      "Bludgeon Vulnerability"
    ),
    magic_vulnerability: parseI16(
      vulnerabilities.magic_vulnerability,
      "Magic Vulnerability"
    ),
    pierce_vulnerability: parseI16(
      vulnerabilities.pierce_vulnerability,
      "Pierce Vulnerability"
    ),
  };
};

const parseValueInRange = (value, name, min, max) => {
  value = BigInt(value || 0n);
  if (value > max || value < min) {
    throw new Error(`${name}: value ${value} out of range (${min}-${max})`);
  }
  return value;
};

const parseU8 = (value, name) => {
  return parseValueInRange(value, name, 0n, 255n);
};

const parseI8 = (value, name) => {
  return parseValueInRange(value, name, -128n, 127n);
};

const parseU16 = (value, name) => {
  return parseValueInRange(value, name, 0n, 65535n);
};

const parseI16 = (value, name) => {
  return parseValueInRange(value, name, -32768n, 32767n);
};

const parseI16Ne0 = (value, name) => {
  value = BigInt(value || 0n);
  if (value === 0n) {
    throw new Error(`${name}: value ${value} cannot be zero`);
  }
  return parseValueInRange(value, name, -32768n, 32767n);
};

const parse0To100 = (value, name) => {
  return parseValueInRange(value, name, 0n, 100n);
};

const parse1To100 = (value, name) => {
  return parseValueInRange(value, name, 1n, 100n);
};

const parseN100To100 = (value, name) => {
  return parseValueInRange(value, name, -100n, 100n);
};

const parseN100To100Ne0 = (value, name) => {
  value = BigInt(value || 0n);
  if (value === 0n) {
    throw new Error(`${name}: value ${value} cannot be zero`);
  }
  return parseValueInRange(value, name, -100n, 100n);
};

export const parseNewAttack = (attack) => {
  try {
    return {
      name: attack.name,
      speed: parseU16(attack.speed, "Speed"),
      chance: parse1To100(attack.chance, "Chance"),
      cooldown: parseU8(attack.cooldown, "Cooldown"),
      success: parseEffectsArray(attack.success || []),
      fail: parseEffectsArray(attack.fail || []),
    };
  } catch (e) {
    console.error(`Error parsing attack: ${attack.name}`);
    throw e;
  }
};

export const parseIdTagAttackStruct = (attack) => {
  if (typeof attack.tag === "string") {
    return new CairoCustomEnum({ Tag: attack.tag });
  }
  if (attack.id != null) {
    return new CairoCustomEnum({ Id: attack.id });
  }
  if (attack.attack != null) {
    return new CairoCustomEnum({ Attack: parseNewAttack(attack.attack) });
  }
  return new CairoCustomEnum({ Attack: parseNewAttack(attack) });
};

export const parseIdTagAttackStructs = (attacks) => {
  return attacks.map(parseIdTagAttackStruct);
};
