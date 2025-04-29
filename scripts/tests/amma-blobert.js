import { getReturns, dataToUint256, callOptions } from "../stark-utils.js";
import { mintEntrypoint } from "../contract-defs.js";
import { cairo } from "starknet";

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

export const mintAmmaTokens = async (caller, signer, contract, fighterIds) => {
  let calls = [];
  for (const fighterId of fighterIds) {
    calls.push(
      signer.getOutsideTransaction(
        callOptions(caller.address),
        contract.populate(mintEntrypoint, {
          fighter: fighterId,
        })
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

export const mintAmmaTokensWithAttacks = async (
  caller,
  signer,
  contract,
  fighterIds
) => {
  const tokenIds = await mintAmmaTokens(caller, signer, contract, fighterIds);
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
