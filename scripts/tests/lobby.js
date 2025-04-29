import { getReturn, callOptions, getReturns } from "../stark-utils.js";

export const sendInviteCall = async (
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
  return await signer.getOutsideTransaction(
    callOptions(caller.address),
    callData
  );
};

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

// export const respondInviteCall = (contract, lobbyId, tokenId, attacks) => {
//   return contract.populate("respond_invite", {
//     challenge_id: lobbyId,
//     token_id: tokenId,
//     attacks,
//   });
// };

export const respondInviteCall = async (
  caller,
  signer,
  contract,
  lobbyId,
  tokenId,
  attacks
) => {
  const callData = contract.populate("respond_invite", {
    challenge_id: lobbyId,
    token_id: tokenId,
    attacks,
  });
  return await signer.getOutsideTransaction(
    callOptions(caller.address),
    callData
  );
};

// export const acceptResponseCall = (contract, lobbyId) => {
//   return contract.populate("accept_response", {
//     challenge_id: lobbyId,
//   });
// };

export const acceptResponseCall = async (caller, signer, contract, lobbyId) => {
  const callData = contract.populate("accept_response", {
    challenge_id: lobbyId,
  });
  return await signer.getOutsideTransaction(
    callOptions(caller.address),
    callData
  );
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

export const makeLobbies = async (
  lobbyContract,
  gameContract,
  caller,
  games
) => {
  let calls = [];
  for (const {
    combatants: [combatant, _],
    accounts: [account1, account2],
  } of games) {
    calls.push(
      await sendInviteCall(
        caller,
        account1,
        lobbyContract,
        account2.address,
        combatant.token.collection_address,
        combatant.token.id,
        combatant.attacks.map((attack) => attack.slot)
      )
    );
  }
  let return_calls = [];

  while (calls.length) {
    const { transaction_hash } = await caller.executeFromOutside(
      calls.splice(0, 50),
      { version: 3 }
    );
    return_calls.push(getReturns(caller, transaction_hash));
  }
  let lobbyIds = (await Promise.all(return_calls)).flatMap((r) =>
    r.map((l) => BigInt(l.data[0]))
  );
  for (let i = 0; i < games.length; i++) {
    games[i].combat_id = lobbyIds[i];
  }
  calls = [];
  for (const {
    combat_id,
    combatants: [_, combatant],
    accounts: [account1, account2],
  } of games) {
    calls.push(
      await respondInviteCall(
        caller,
        account2,
        lobbyContract,
        combat_id,
        combatant.token.id,
        combatant.attacks.map((attack) => attack.slot)
      )
    );
    calls.push(
      await acceptResponseCall(caller, account1, lobbyContract, combat_id)
    );
  }
  while (calls.length) {
    await caller.executeFromOutside(calls.splice(0, 50), { version: 3 });
  }

  let combatants = [];
  while (lobbyIds.length) {
    combatants.push(
      ...(await Promise.all(
        lobbyIds.splice(0, 50).map((id) => gameContract.combatants(id))
      ))
    );
  }
  for (let i = 0; i < games.length; i++) {
    games[i].combatants[0].id = combatants[i][0];
    games[i].combatants[1].id = combatants[i][1];
  }
};
