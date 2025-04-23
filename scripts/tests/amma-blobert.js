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
  return [
    await contract.get_attack_slots(tokenId, ammaAttackSlots),
    ammaAttackSlots,
  ];
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
    attack_slots: ammaAttackSlots,
  };
};

export const mintAmmaTokensWithAttacks = async (
  caller,
  signer,
  contract,
  fighterIds
) => {
  const tokenIds = await mintAmmaTokens(caller, signer, contract, fighterIds);
  const tokens = tokenIds.map(async (tokenId) => {
    const [attacks, attackSlots] = await getAmmaAttacks(contract, tokenId);
    return {
      collection_address: contract.address,
      id: tokenId,
      attacks,
      attack_slots: attackSlots,
    };
  });

  return Promise.all(tokens);
};
