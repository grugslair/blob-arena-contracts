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
  ammaBlobertContractTag,
  mintEntrypoint,
  lobbyContractTag,
  gameContractTag,
} from "../contract-defs.js";
import { cairo, Account } from "starknet";
import { makeLobby } from "./lobby.js";
import { runCombatRound } from "./game.js";
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

const ammaAttackSlots = [
  cairo.tuple(0, 0),
  cairo.tuple(0, 1),
  cairo.tuple(0, 2),
  cairo.tuple(0, 3),
];

const mintAmmaToken = async (account, contract, fighterId) => {
  const callData = contract.populate(mintEntrypoint, {
    fighter: fighterId,
  });
  const response = await account.execute(callData, contract.abi, {
    version: 3,
  });
  return dataToUint256(
    (await getReturns(account, response.transaction_hash))[0].data
  );
};
const getAmmaAttacks = async (contract, tokenId) => {
  return await contract.get_attack_slots(tokenId, ammaAttackSlots);
};

const makeToken = async (account, contract, fighterId) => {
  const tokenId = await mintAmmaToken(account, contract, fighterId);
  return {
    token_id: tokenId,
    attacks: await getAmmaAttacks(contract, tokenId),
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
  const ammaContract = await account_manifest.getContract(
    ammaBlobertContractTag
  );
  const lobbyContract = await account_manifest.getContract(lobbyContractTag);
  const gameContract = await account_manifest.getContract(gameContractTag);

  const player1Tokens = [];
  const player2Tokens = [];
  let wins = {};
  for (let i = 1; i <= 9; i++) {
    player1Tokens.push(await makeToken(account1, ammaContract, i));
    player2Tokens.push(await makeToken(account2, ammaContract, i));
    wins[i] = 0;
  }
  console.log(player1Tokens);

  for (let i = 0; i < player1Tokens.length; i++) {
    const token1 = player1Tokens[i];
    for (let j = 0; j < player2Tokens.length; j++) {
      const token2 = player2Tokens[j];
      console.log(`\n\nFighter ${i + 1} vs Fighter ${j + 1}`);
      const [gameId, combatant1, combatant2] = await makeLobby(
        account1,
        account2,
        lobbyContract,
        gameContract,
        ammaContract.address,
        token1.token_id,
        ammaAttackSlots,
        token2.token_id,
        ammaAttackSlots
      );
      console.log(`Lobby ID: ${toHexString(gameId)}`);
      console.log(`${toHexString(combatant1)} vs ${toHexString(combatant2)}`);

      let n = 1;
      while (
        (await gameContract.combat_phase(gameId)).activeVariant() === "Commit"
      ) {
        const attack1 = randomElement(token1.attacks);
        const attack2 = randomElement(token2.attacks);
        console.log(
          `Round ${n} Attacks: 0x${attack1.toString(
            16
          )} vs 0x${attack2.toString(16)}`
        );
        await runCombatRound(
          account1,
          account2,
          gameContract,
          gameId,
          combatant1,
          combatant2,
          attack1,
          attack2
        );
        n++;
      }
      const winner = (await gameContract.combat_phase(gameId)).unwrap();
      let winningFighter = 0;
      if (winner === combatant1) {
        winningFighter = i + 1;
      } else if (winner === combatant2) {
        winningFighter = j + 1;
      }
      wins[winningFighter]++;
      console.log(`Winning Fighter: ${winningFighter}`);
    }
  }
  console.log("Wins: ");
  console.log(wins);
};

const randomElement = (array) => {
  return array[Math.floor(Math.random() * array.length)];
};

if (process.argv[1] === import.meta.filename) {
  await main();
}
