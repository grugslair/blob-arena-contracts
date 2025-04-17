import { getReturn, callOptions } from "../stark-utils.js";

export const sendInvite = async (
  caller,
  signer,
  contract,
  receiver,
  collectionAddress,
  tokenId,
  attacks
) => {
  const callData = contract.populate("send_invite", {
    initiator: 0,
    time_limit: 0,
    collection_address: collectionAddress,
    token_id: tokenId,
    receiver,
    attacks,
  });
  let call1 = await signer.getOutsideTransaction(
    callOptions(caller.address),
    callData
  );
  const { transaction_hash } = await caller.executeFromOutside(call1, {
    version: 3,
  });

  return (await getReturn(caller, transaction_hash))[0];
};

export const respondInviteCall = (contract, lobbyId, tokenId, attacks) => {
  return contract.populate("respond_invite", {
    challenge_id: lobbyId,
    token_id: tokenId,
    attacks,
  });
};

export const acceptResponseCall = (contract, lobbyId) => {
  return contract.populate("accept_response", {
    challenge_id: lobbyId,
  });
};

export const makeLobby = async (
  account,
  account1,
  account2,
  lobbyContract,
  gameContract,
  collectionAddress,
  tokenId1,
  attacks1,
  tokenId2,
  attacks2
) => {
  const lobbyId = await sendInvite(
    account,
    account1,
    lobbyContract,
    account2.address,
    collectionAddress,
    tokenId1,
    attacks1
  );
  const respondCall = respondInviteCall(
    lobbyContract,
    lobbyId,
    tokenId2,
    attacks2
  );
  const acceptCall = acceptResponseCall(lobbyContract, lobbyId);
  const calls = [
    await account2.getOutsideTransaction(
      callOptions(account.address),
      respondCall
    ),
    await account1.getOutsideTransaction(
      callOptions(account.address),
      acceptCall
    ),
  ];
  const { transaction_hash } = await account.executeFromOutside(calls, {
    version: 3,
  });
  const [combatant1, combatant2] = await gameContract.combatants(lobbyId);
  return [lobbyId, combatant1, combatant2];
};
