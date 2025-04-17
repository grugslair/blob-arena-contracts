import { loadAccountManifestFromCmdArgs, newAccounts } from "../stark-utils.js";
import {
  ammaBlobertContractTag,
  lobbyContractTag,
  pvpContractTag,
} from "../contract-defs.js";
import { makeLobby } from "./lobby.js";
import { runRounds } from "./pvp.js";
import { randomIndexes } from "../utils.js";
import { mintAmmaTokenWithAttacks } from "./amma-blobert.js";

const accountClassHash =
  "0x07489e371db016fcd31b78e49ccd201b93f4eab60af28b862390e800ec9096e2";

const main = async () => {
  const account_manifest = await loadAccountManifestFromCmdArgs();
  const account = account_manifest.account;
  const ammaContract = await account_manifest.getContract(
    ammaBlobertContractTag
  );
  const lobbyContract = await account_manifest.getContract(lobbyContractTag);
  const gameContract = await account_manifest.getContract(pvpContractTag);
  console.log("Deploying new accounts");
  const [account1, account2] = await newAccounts(account, accountClassHash, 2);
  console.log("Accounts deployed");
  const player1Tokens = [];
  const player2Tokens = [];

  let wins = { 0: 0 };
  for (let i = 1; i <= 9; i++) {
    player1Tokens.push(
      await mintAmmaTokenWithAttacks(account, account1, ammaContract, i)
    );
    player2Tokens.push(
      await mintAmmaTokenWithAttacks(account, account2, ammaContract, i)
    );
    wins[i] = 0;
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
        ammaContract.address,
        token1.token_id,
        attackSlots1,
        token2.token_id,
        attackSlots2
      );

      const combatant1 = {
        id: combatantId1,
        fighter: i + 1,
        token_id: token1.token_id,
        attacks: attacks1,
        attack_slots: attackSlots1,
      };
      const combatant2 = {
        id: combatantId2,
        fighter: j + 1,
        token_id: token2.token_id,
        attacks: attacks2,
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
        `Game:${gameId}  Fighter ${combatant1.fighter} vs Fighter ${combatant2.fighter}`
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
        let winningFighter = 0;
        if (game.winner === game.combatant1.id) {
          winningFighter = game.combatant1.fighter;
        } else if (game.winner === game.combatant2.id) {
          winningFighter = game.combatant2.fighter;
        }
        wins[winningFighter]++;
      }
    }
    for (const game of runningGames) {
      game.round++;
    }
  }
  console.log("Wins: ");
  console.log(wins);
};

if (process.argv[1] === import.meta.filename) {
  await main();
}
