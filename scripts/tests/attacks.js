import { hash, CallData, num } from "starknet";
import { attackIdFromInputEntrypoint } from "../contract-defs.js";
import { randomElement } from "../utils.js";
import {
  namespaceNameToHash,
  parseDojoEvent,
  eventEmittedHash,
} from "../dojo.js";
import { byteDataToString, getAllEvents } from "../stark-utils.js";

export const attackIdFromInput = (contractAbi, input) => {
  const callData = new CallData(contractAbi);
  const attackInput = callData.compile(attackIdFromInputEntrypoint, input);
  return hash.computePoseidonHashOnElements(attackInput);
};

export const getUseableAttacks = (attacks, round) => {
  return attacks.filter(
    ({ cooldown, lastUsed }) =>
      cooldown === 0 || lastUsed === 0 || cooldown + lastUsed < round
  );
};

export const randomUseableAttack = (attacks, round) => {
  const attack = randomElement(getUseableAttacks(attacks, round));
  if (!attack) {
    return BigInt(0);
  }
  attack.lastUsed = BigInt(round);
  return BigInt(attack.id);
};

export const getAttacks = async (world, contract, attackIds) => {
  const keyFilter = [
    [eventEmittedHash],
    [namespaceNameToHash("blob_arena-AttackName")],
  ];
  const events = await getAllEvents(world.providerOrAccount, {
    address: world.address,
    keys: keyFilter,
    chunk_size: 1024,
  });
  const attacks = Object.fromEntries(
    (await Promise.all(attackIds.map((a) => contract.attack(a)))).map((a) => [
      a.id,
      a,
    ])
  );

  for (const event of events) {
    const {
      keys: [attackIdHex],
      values,
    } = parseDojoEvent(event);
    const attackId = BigInt(attackIdHex);
    if (attackId in attacks) {
      attacks[attackId].name = byteDataToString(values);
    }
  }
  return attacks;
};

export const makeAttack = (attack, attacks) => {
  const { id, slot } = attack;
  return {
    id,
    slot,
    ...attacks[id],
    lastUsed: 0,
  };
};
