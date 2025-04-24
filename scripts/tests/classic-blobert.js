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

export const mintFreeTokens = async (caller, signer, contract, number) => {
  let calls = [];
  for (let i = 0; i < number; i++) {
    calls.push(
      signer.getOutsideTransaction(
        callOptions(caller.address),
        contract.populate(mintEntrypoint)
      )
    );
  }

  const { transaction_hash } = await caller.executeFromOutside(
    await Promise.all(calls),
    {
      version: 3,
    }
  );
  const returns = await getReturns(caller, transaction_hash);
  return returns.map((r) => dataToUint256(r.data));
};

export const getFreeAttacks = async (contract, tokenId) => {
  let allAttackSlots = [];

  for (let i = 1; i <= 5; i++) {
    for (let j = 0; j < 5; j++) {
      allAttackSlots.push(cairo.tuple(i, j));
    }
  }

  const maybeAttacks = await contract.get_attack_slots(tokenId, allAttackSlots);
  let attacks = [];
  for (let i = 0; i < maybeAttacks.length; i++) {
    if (maybeAttacks[i]) {
      attacks.push({
        id: maybeAttacks[i],
        slot: allAttackSlots[i],
      });
    }
  }

  return attacks;
};

export const mintFreeTokenWithAttacks = async (caller, signer, contract) => {
  const tokenId = await mintFreeToken(caller, signer, contract);
  console.log(`Token Id: ${uint256ToHex(tokenId)}`);
  const [attacks, stats] = await Promise.all([
    getFreeAttacks(contract, tokenId),
    contract.get_stats(tokenId),
  ]);

  return {
    collection_address: contract.address,
    id: tokenId,
    attacks,
    stats,
  };
};

export const mintFreeTokensWithAttacks = async (
  caller,
  signer,
  contract,
  number
) => {
  const tokenIds = await mintFreeTokens(caller, signer, contract, number);
  const [attacks, stats] = await Promise.all([
    Promise.all(tokenIds.map((tokenId) => getFreeAttacks(contract, tokenId))),
    Promise.all(tokenIds.map((tokenId) => contract.get_stats(tokenId))),
  ]);
  let tokens = [];
  for (let i = 0; i < tokenIds.length; i++) {
    tokens.push({
      collection_address: contract.address,
      id: tokenIds[i],
      attacks: attacks[i],
      stats: stats[i],
    });
  }
  return tokens;
};
