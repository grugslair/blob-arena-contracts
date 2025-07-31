import { makeCairoEnum, parseEnumObject } from "./stark-utils.js";
import { CairoCustomEnum } from "starknet";

const makeEffectStruct = (effect) => {
  let [key, affect] = parseEnumObject(effect.affect);

  if (key == "Ability") {
    effect.affect.Ability = makeCairoEnum(value.ability);
  } else if (["Health", "Abilities"].includes(key)) {
    effect.affect = effect.affect;
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
