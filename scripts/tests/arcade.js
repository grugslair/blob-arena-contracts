import {
  loadAccountManifestFromCmdArgs,
  uint256ToHex,
  getReturns,
  dataToUint256,
  newAccount,
  callOptions,
} from "../stark-utils.js";
import { randomIndexes } from "../utils.js";
import {
  freeBlobertContractTag,
  mintEntrypoint,
  lobbyContractTag,
  pvpContractTag,
} from "../contract-defs.js";
import { cairo, Account, hash } from "starknet";
import { makeLobby } from "./lobby.js";
import { runRounds } from "./pvp.js";
import { bigIntToHex } from "web3-eth-accounts";

const ammAChallengeId =
  "0x079fdc2acff4bbab416ea08f321087b0b99a53099443852175fd49b9ba2540fe";
const classicChallengeId =
  "0x033bd13f2718e9b2a90b3b8c7847b11c9eb5ce81c95009998380ab95b343f53d";

const accountClassHash =
  "0x07489e371db016fcd31b78e49ccd201b93f4eab60af28b862390e800ec9096e2";

const makeAttack = (caller, signer, attacks) => {};

const main = async () => {
  const account_manifest = await loadAccountManifestFromCmdArgs();
  const account = account_manifest.account;
  const freeContract = await account_manifest.getContract(
    freeBlobertContractTag
  );
  const lobbyContract = await account_manifest.getContract(lobbyContractTag);
  const gameContract = await account_manifest.getContract(pvpContractTag);

  console.log("Deploying new accounts");
  const account1 = await newAccount(account, accountClassHash);
  console.log("Accounts deployed");
  const player1Tokens = [];
  const player2Tokens = [];
  for (let i = 0; i < 6; i++) {
    player1Tokens.push(
      await mintFreeTokenWithAttacks(account, account1, freeContract)
    );
    player2Tokens.push(
      await mintFreeTokenWithAttacks(account, account2, freeContract)
    );
  }
  let games = [];

  for (let i = 0; i < player1Tokens.length; i++) {
    const token1 = player1Tokens[i];
    for (let j = 0; j < player2Tokens.length; j++) {
      const token2 = player2Tokens[j];

      const attackIndexes1 = randomIndexes(token1.attack_slots.length, 4);
      const attackIndexes2 = randomIndexes(token2.attack_slots.length, 4);
      const attacks1 = attackIndexes1.map((index) => token1.attacks[index]);
      const attacks2 = attackIndexes2.map((index) => token2.attacks[index]);
      const attackSlots1 = attackIndexes1.map(
        (index) => token1.attack_slots[index]
      );
      const attackSlots2 = attackIndexes2.map(
        (index) => token2.attack_slots[index]
      );
      const [gameId, combatantId1, combatantId2] = await makeLobby(
        account,
        account1,
        account2,
        lobbyContract,
        gameContract,
        freeContract.address,
        token1.token_id,
        attackSlots1,
        token2.token_id,
        attackSlots2
      );

      const combatant1 = {
        id: combatantId1,
        token_id: token1.token_id,
        attacks: Object.fromEntries(attacks1.map((a) => [a, 0])),
        attack_slots: attackSlots1,
      };
      const combatant2 = {
        id: combatantId2,
        token_id: token2.token_id,
        attacks: Object.fromEntries(attacks2.map((a) => [a, 0])),
        attack_slots: attackSlots2,
      };
      games.push({
        combat_id: gameId,
        combatant1,
        combatant2,
        round: 1,
        winner: null,
      });

      console.log(
        `Game:${gameId}    ${bigIntToHex(combatant1.id)} vs ${bigIntToHex(
          combatant2.id
        )}`
      );
    }
  }

  const maxRunningGames = 9;
  while (games.filter((game) => game.winner === null).length) {
    const runningGames = games
      .filter((game) => game.winner === null)
      .slice(0, maxRunningGames);

    await runRounds(account, account1, account2, gameContract, runningGames);
    for (const game of runningGames) {
      const phase = await gameContract.combat_phase(game.combat_id);
      if (phase.activeVariant() !== "Commit") {
        game.winner = phase.unwrap();
      }
    }
    for (const game of runningGames) {
      game.round++;
    }
  }
};

if (process.argv[1] === import.meta.filename) {
  await main();
}
