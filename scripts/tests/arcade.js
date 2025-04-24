import { callOptions, getReturns } from "../stark-utils.js";
import { randomIndexes } from "../utils.js";
import { randomUseableAttack } from "./attacks.js";

export const runArcadeGameCall = (
  caller,
  signer,
  contract,
  challenge,
  attacks
) => {
  return signer.getOutsideTransaction(
    callOptions(caller.address),
    contract.populate("attack", {
      game_id: challenge.game.id,
      attack_id: randomUseableAttack(
        attacks,
        challenge.game.combatant.attacks,
        challenge.game.round
      ),
    })
  );
};
export const nextChallengeRoundCall = (caller, signer, contract, challenge) => {
  return signer.getOutsideTransaction(
    callOptions(caller.address),
    contract.populate("next_challenge_round", {
      attempt_id: challenge.attempt_id,
    })
  );
};
export const endChallengeCall = (caller, signer, contract, challenge) => {
  return signer.getOutsideTransaction(
    callOptions(caller.address),
    contract.populate("end_challenge", {
      attempt_id: challenge.attempt_id,
    })
  );
};

export const respawnArcadeChallengeCall = (
  caller,
  signer,
  contract,
  challenge
) => {
  return signer.getOutsideTransaction(
    callOptions(caller.address),
    contract.populate("respawn_challenge", {
      attempt_id: challenge.attempt_id,
    })
  );
};

export class ChallengeAttempt {
  constructor(contract, challengeId, token, attacksUsed) {
    this.challengeId = challengeId;
    this.contract = contract;
    this.respawns = 0;
    this.stage = 0;
    this.status = "Active";
    this.attacksUsed = attacksUsed;
    this.token = token;
    this.games = {};
    this.attemptId = null;
    this.playerStats = null;
  }
  startCall(caller) {
    return signer.getOutsideTransaction(
      callOptions(caller.address),
      contract.populate("start_challenge", {
        challenge_id: this.challengeId,
        collection_address: this.token.collection_address,
        token_id: this.token.id,
        attacks: this.attacksUsed,
      })
    );
  }

  nextStageCall(caller) {
    return signer.getOutsideTransaction(
      callOptions(caller.address),
      contract.populate("next_challenge_round", {
        attempt_id: challenge.attempt_id,
      })
    );
  }

  respawnCall(caller) {
    return signer.getOutsideTransaction(
      callOptions(caller.address),
      contract.populate("respawn_challenge", {
        attempt_id: challenge.attempt_id,
      })
    );
  }

  nextStage(game) {
    this.setCurrentGame(game);
    this.stage += 1;
    this.games[this.stage] = [this.currentGame];
  }

  respawn(game) {
    this.setCurrentGame(game);
    this.respawns += 1;
    this.games[this.stage].push(this.currentGame);
  }

  setCurrentGame(game) {
    this.currentGame = {
      id: game.id,
      combatants: {
        [game.combatant_id]: {
          id: game.combatant_id,
          attacks: Object.fromEntries(this.attacksUsed.map((a) => [a, 0])),
        },
        [game.opponent_id]: {},
      },
      round: 1,
      results: [],
      phase: "Active",
    };
  }

  endChallengeCall(caller) {
    return signer.getOutsideTransaction(
      callOptions(caller.address),
      contract.populate("end_challenge", {
        attempt_id: challenge.attempt_id,
      })
    );
  }
}

export const runArcadeChallengeGames = async (
  caller,
  signer,
  contract,
  dojoParser,
  challenges,
  attacks
) => {
  let calls = [];
  let activeChallenges = [];
  let eventCalls = [];
  for (let i = 0; i < challenges.length; i++) {
    const challenge = challenges[i];
    if (challenge.status === "Active") {
      activeChallenges.push(challenge);
      calls.push(
        runArcadeGameCall(caller, signer, contract, challenge, attacks)
      );
      challenge.game.round++;
    }
  }
  const { transaction_hash: roundsTxHash } = await caller.executeFromOutside(
    await Promise.all(calls),
    {
      version: 3,
    }
  );

  const game_phases = await Promise.all(
    activeChallenges.map((c) => contract.game_phase(c.game.id))
  );
  calls = [];
  let newGameChallenges = [];
  for (let i = 0; i < activeChallenges.length; i++) {
    const challenge = activeChallenges[i];
    const game_phase = game_phases[i].activeVariant();
    challenge.game.status = game_phase;
    if (game_phase === "PlayerWon") {
      if (challenge.stage < 10) {
        newGameChallenges.push(challenge);
        calls.push(nextChallengeRoundCall(caller, signer, contract, challenge));
        challenge.stage = challenge.stage + 1;
      } else {
        endChallengeCall(caller, signer, contract, challenge);
        challenge.games.push(challenge.game);
        challenge.status = "PlayerWon";
      }
    } else if (game_phase === "PlayerLost") {
      if (challenge.respawns < 3) {
        newGameChallenges.push(challenge);
        calls.push(
          respawnArcadeChallengeCall(caller, signer, contract, challenge)
        );
        challenge.respawns++;
      } else {
        endChallengeCall(caller, signer, contract, challenge);
        challenge.games.push(challenge.game);
        challenge.status = "PlayerLost";
      }
    }
  }
  const { transaction_hash: newGamesTxHash } = await caller.executeFromOutside(
    await Promise.all(calls),
    {
      version: 3,
    }
  );

  const newGameIds = (await getReturns(caller, newGamesTxHash)).map(
    (x) => x.data[0]
  );
  const newGames = await Promise.all(
    newGameIds.map((gameId) => contract.game(gameId))
  );
  for (let i = 0; i < newGameChallenges.length; i++) {
    const challenge = newGameChallenges[i];
    const newGame = newGames[i];
    challenge.games.push(challenge.game);
    challenge.game = {
      id: newGameIds[i],
      combatant: {
        id: newGame.combatant_id,
        attacks: challenge.game.combatant.attacks,
      },
      round: 1,
      results: [],
      phase: "Active",
    };
  }
  console.log("------------------------------------------------------------");
  console.log(challenges);
  return newGameChallenges;
};

export const startArcadeChallengeCall = (
  caller,
  signer,
  contract,
  ChallengeId,
  collectionAddress,
  tokenId,
  attacks
) => {
  return signer.getOutsideTransaction(
    callOptions(caller.address),
    contract.populate("start_challenge", {
      challenge_id: ChallengeId,
      collection_address: collectionAddress,
      token_id: tokenId,
      attacks,
    })
  );
};

export const startArcadeChallenges = async (
  caller,
  signer,
  contract,
  challengeId,
  tokens
) => {
  let calls = [];
  let attacksUsed = [];
  for (const token of tokens) {
    let indexes = randomIndexes(token.attacks.length, 4);
    attacksUsed.push(
      Object.fromEntries(indexes.map((index) => [token.attacks[index], 0]))
    );
    calls.push(
      startArcadeChallengeCall(
        caller,
        signer,
        contract,
        challengeId,
        token.collection_address,
        token.id,
        indexes.map((index) => token.attack_slots[index])
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
  const games = await Promise.all(
    returns.map(({ data: [_, game_id] }) => contract.game(game_id))
  );
  let attempts = [];
  for (let i = 0; i < tokens.length; i++) {
    const game = games[i];
    const [attempt_id, game_id] = returns[i].data;
    attempts.push({
      token: tokens[i],
      challenge_id: challengeId,
      attempt_id,
      respawns: 0,
      stage: 1,
      status: "Active",
      game: {
        id: game_id,
        combatant: {
          id: game.combatant_id,
          attacks: attacksUsed[i],
        },
        results: [],
        round: 1,
        status: "Active",
      },
      games: [],
    });
  }
  return attempts;
};

export const mintPaidArcadeGames = async (
  account,
  contract,
  player,
  amount
) => {
  await account.execute(
    contract.populate("mint_paid_games", { player, amount }),
    { version: 3 }
  );
};

export const mintFreeArcadeGames = async (
  account,
  contract,
  player,
  amount
) => {
  await account.execute(
    contract.populate("mint_free_games", { player, amount }),
    { version: 3 }
  );
};
