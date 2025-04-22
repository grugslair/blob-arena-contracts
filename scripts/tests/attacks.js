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

export const getUseableAttacks = (allAttacks, attacks, round) => {
  return Object.entries(attacks)
    .filter(
      ([key, value]) =>
        allAttacks[key].cooldown === 0 ||
        value === 0 ||
        allAttacks[key].cooldown + value < round
    )
    .map(([key, _]) => BigInt(key));
};

export const randomUseableAttack = (allAttacks, attacks, round) => {
  return randomElement(getUseableAttacks(allAttacks, attacks, round));
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
