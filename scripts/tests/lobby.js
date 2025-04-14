import { getReturn } from "../stark-utils.js";

export const sendInvite = async (
  account,
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
  const response = await account.execute(callData, contract.abi, {
    version: 3,
  });

  return (await getReturn(account, response.transaction_hash))[0];
};

export const respondInvite = async (
  account,
  contract,
  lobbyId,
  tokenId,
  attacks
) => {
  await account.execute(
    contract.populate("respond_invite", {
      challenge_id: lobbyId,
      token_id: tokenId,
      attacks,
    }),
    contract.abi,
    {
      version: 3,
    }
  );
};

export const acceptResponse = async (account, contract, lobbyId) => {
  await account.execute(
    contract.populate("accept_response", {
      challenge_id: lobbyId,
    }),
    contract.abi,
    {
      version: 3,
    }
  );
};

export const makeLobby = async (
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
    account1,
    lobbyContract,
    account2.address,
    collectionAddress,
    tokenId1,
    attacks1
  );
  await respondInvite(account2, lobbyContract, lobbyId, tokenId2, attacks2);
  await acceptResponse(account1, lobbyContract, lobbyId);
  const [combatant1, combatant2] = await gameContract.combatants(lobbyId);
  return [lobbyId, combatant1, combatant2];
};
