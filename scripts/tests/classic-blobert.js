import {
  uint256ToHex,
  getReturns,
  dataToUint256,
  callOptions,
} from "../stark-utils.js";
import { mintEntrypoint } from "../contract-defs.js";
import { cairo } from "starknet";

export const mintFreeToken = async (caller, signer, contract) => {
  const outsideCall = await signer.getOutsideTransaction(
    callOptions(caller.address),
    contract.populate(mintEntrypoint)
  );
  const { transaction_hash } = await caller.executeFromOutside(outsideCall, {
    version: 3,
  });
  return dataToUint256((await getReturns(caller, transaction_hash))[0].data);
};

export const getFreeAttacks = async (contract, tokenId) => {
  let allAttackSlots = [];

  for (let i = 1; i <= 5; i++) {
    for (let j = 0; j < 5; j++) {
      allAttackSlots.push(cairo.tuple(i, j));
    }
  }

  const maybeAttacks = await contract.get_attack_slots(tokenId, allAttackSlots);
  let attackSlots = [];
  let attacks = [];
  for (let i = 0; i < maybeAttacks.length; i++) {
    if (maybeAttacks[i]) {
      attacks.push(maybeAttacks[i]);
      attackSlots.push(allAttackSlots[i]);
    }
  }

  return [attacks, attackSlots];
};

export const mintFreeTokenWithAttacks = async (caller, signer, contract) => {
  const tokenId = await mintFreeToken(caller, signer, contract);
  console.log(`Token Id: ${uint256ToHex(tokenId)}`);
  const [attacks, attackSlots] = await getFreeAttacks(contract, tokenId);
  return {
    token_id: tokenId,
    attacks,
    attack_slots: attackSlots,
  };
};
