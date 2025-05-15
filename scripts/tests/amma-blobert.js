import {
  getReturns,
  getReturn,
  dataToUint256,
  callOptions,
} from "../stark-utils.js";
import { ammaMintFreeEntrypoint, mintEntrypoint } from "../contract-defs.js";
import { cairo } from "starknet";

export const ammaFighterIds = [
  1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
];

export const ammaAttackSlots = [
  cairo.tuple(0, 0),
  cairo.tuple(0, 1),
  cairo.tuple(0, 2),
  cairo.tuple(0, 3),
];

export const mintAmmaToken = async (caller, account, contract, fighterId) => {
  const outsideCall = await account.getOutsideTransaction(
    callOptions(caller.address),
    contract.populate(mintEntrypoint, {
      fighter: fighterId,
    })
  );

  const { transaction_hash } = await caller.executeFromOutside(outsideCall, {
    version: 3,
  });
  return dataToUint256((await getReturns(caller, transaction_hash))[0].data);
};

export const mintAmmaTokens = async (caller, signer, contract) => {
  let calls = [
    signer.getOutsideTransaction(
      callOptions(caller.address),
      contract.populate(ammaMintFreeEntrypoint, {})
    ),
  ];

  const { transaction_hash } = await caller.executeFromOutside(
    await Promise.all(calls),
    {
      version: 3,
    }
  );
  const returns = await getReturn(caller, transaction_hash);
  return [
    dataToUint256(returns.slice(1, 3)),
    dataToUint256(returns.slice(3, 5)),
  ];
};

const getAmmaAttacks = async (contract, tokenId) => {
  const attackIds = await contract.get_attack_slots(tokenId, ammaAttackSlots);
  let attacks = [];
  for (let i = 0; i < ammaAttackSlots.length; i++) {
    attacks.push({
      id: attackIds[i],
      slot: ammaAttackSlots[i],
    });
  }
  return attacks;
};

export const mintAmmaTokenWithAttacks = async (
  caller,
  account,
  contract,
  fighterId
) => {
  const tokenId = await mintAmmaToken(caller, account, contract, fighterId);
  return {
    token_id: tokenId,
    attacks: await getAmmaAttacks(contract, tokenId),
  };
};

export const mintAmmaTokensWithAttacks = async (caller, signer, contract) => {
  const tokenIds = await mintAmmaTokens(caller, signer, contract);
  const [attacks, stats] = await Promise.all([
    Promise.all(tokenIds.map((tokenId) => getAmmaAttacks(contract, tokenId))),
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
