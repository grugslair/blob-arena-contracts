import {
  loadJson,
  splitCallDescriptions,
  loadAccountManifestFromCmdArgs,
  makeCairoEnum,
  pascalCase,
  getReturns,
  dataToUint256,
} from "../stark-utils.js";
import {
  freeBlobertContractTag,
  mintEntrypoint,
  lobbyContractTag,
  gameContractTag,
} from "../contract-defs.js";
import { cairo, Account } from "starknet";
import { makeLobby } from "./lobby.js";
import { runBattle } from "./game.js";
const accounts = [
  {
    address:
      "0x13d9ee239f33fea4f8785b9e3870ade909e20a9599ae7cd62c1c292b73af1b7",
    private_key:
      "0x1c9053c053edf324aec366a34c6901b1095b07af69495bffec7d7fe21effb1b",
  },
  {
    address:
      "0x17cc6ca902ed4e8baa8463a7009ff18cc294fa85a94b4ce6ac30a9ebd6057c7",
    private_key:
      "0x14d6672dcb4b77ca36a887e9a11cd9d637d5012468175829e9c6e770c61642",
  },
];

const mintFreeToken = async (account, contract) => {
  const response = await account.execute(
    contract.populate(mintEntrypoint),
    contract.abi,
    {
      version: 3,
    }
  );
  return dataToUint256(
    (await getReturns(account, response.transaction_hash))[0].data
  );
};
const getFreeAttacks = async (contract, tokenId) => {
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

const mintFreeTokenWithAttacks = async (account, contract) => {
  const tokenId = await mintFreeToken(account, contract);
  const [attacks, attackSlots] = await getFreeAttacks(contract, tokenId);
  return {
    token_id: tokenId,
    attacks,
    attack_slots: attackSlots,
  };
};

const getAccount = (nodeUrl, account) => {
  return new Account({ nodeUrl }, account.address, account.private_key);
};

const uint256ToString = (value) => {
  return (
    "0x" +
    BigInt(value.high).toString(16) +
    BigInt(value.low).toString(16).padStart(32, "0")
  );
};

const toHexString = (value) => {
  return "0x" + BigInt(value).toString(16);
};

const main = async () => {
  const account_manifest = await loadAccountManifestFromCmdArgs();
  const account1 = getAccount(account_manifest.rpc_url, accounts[0]);
  const account2 = getAccount(account_manifest.rpc_url, accounts[1]);
  const freeContract = await account_manifest.getContract(
    freeBlobertContractTag
  );
  const lobbyContract = await account_manifest.getContract(lobbyContractTag);
  const gameContract = await account_manifest.getContract(gameContractTag);

  const player1Tokens = [];
  const player2Tokens = [];

  for (let i = 0; i < 5; i++) {
    player1Tokens.push(await mintFreeTokenWithAttacks(account1, freeContract));
    player2Tokens.push(await mintFreeTokenWithAttacks(account2, freeContract));
  }

  for (let i = 0; i < player1Tokens.length; i++) {
    const token1 = player1Tokens[i];
    for (let j = 0; j < player2Tokens.length; j++) {
      const token2 = player2Tokens[j];

      const [gameId, combatantId1, combatantId2] = await makeLobby(
        account1,
        account2,
        lobbyContract,
        gameContract,
        freeContract.address,
        token1.token_id,
        token1.attack_slots,
        token2.token_id,
        token2.attack_slots
      );
      const combatant1 = {
        combatant_id: combatantId1,
        attacks: token1.attacks,
      };
      const combatant2 = {
        combatant_id: combatantId2,
        attacks: token2.attacks,
      };
      console.log(`\n\nLobby ID: ${toHexString(gameId)}`);
      console.log(
        `${toHexString(combatant1.combatant_id)} vs ${toHexString(
          combatant2.combatant_id
        )}`
      );
      await runBattle(
        account1,
        account2,
        gameContract,
        gameId,
        combatant1,
        combatant2
      );
      const winner = (await gameContract.combat_phase(gameId)).unwrap();
      console.log(`Winning Fighter: ${toHexString(winner)}`);
    }
  }
};

if (process.argv[1] === import.meta.filename) {
  await main();
}
