import { callOptions, getReturns } from "../stark-utils.js";
import { randomUseableAttack, resetAttack } from "./attacks.js";

export class ChallengeAttempt {
  constructor(
    signer,
    contract,
    gameContract,
    challengeId,
    token,
    attacks,
    allAttacks
  ) {
    this.challengeId = challengeId;
    this.contract = contract;
    this.gameContract = gameContract;
    this.signer = signer;
    this.respawns = 0;
    this.stage = 0;
    this.status = "Active";
    this.attacks = attacks;
    this.token = token;
    this.games = {};
    this.attemptId = null;
    this.playerStats = null;
    this.allAttacks = allAttacks;
    this.lastAttack = null;
  }
  startCall(caller) {
    return this.signer.getOutsideTransaction(
      callOptions(caller.address),
      this.contract.populate("start_challenge", {
        challenge_id: this.challengeId,
        collection_address: this.token.collection_address,
        token_id: this.token.id,
        attacks: this.attacks.map((attack) => attack.slot),
      })
    );
  }
  async start(attemptId, gameId) {
    this.attemptId = attemptId;
    await this.nextStage(gameId);
  }
  attackCall = (caller) => {
    this.currentGame.round += BigInt(1);
    this.lastAttack = randomUseableAttack(this.attacks, this.currentGame.round);
    return this.signer.getOutsideTransaction(
      callOptions(caller.address),
      this.contract.populate("attack", {
        game_id: this.currentGame.id,
        attack_id: this.lastAttack,
      })
    );
  };
  nextStageCall(caller) {
    return this.signer.getOutsideTransaction(
      callOptions(caller.address),
      this.contract.populate("next_challenge_round", {
        attempt_id: this.attemptId,
      })
    );
  }

  respawnCall(caller) {
    return this.signer.getOutsideTransaction(
      callOptions(caller.address),
      this.contract.populate("respawn_challenge", {
        attempt_id: this.attemptId,
      })
    );
  }

  async nextStage(gameId) {
    await this.setCurrentGame(gameId);
    this.stage += 1;
    this.games[this.stage] = [this.currentGame];
  }

  async respawn(gameId) {
    await this.setCurrentGame(gameId);
    this.respawns += 1;
    this.games[this.stage].push(this.currentGame);
  }

  async setCurrentGame(gameId) {
    const game = await this.contract.game(gameId);
    const [player, opponentState, opponentToken] = await Promise.all([
      this.gameContract.combatant_state(game.combatant_id),
      this.gameContract.combatant_state(game.opponent_id),
      this.contract.opponent_token(game.opponent_token),
    ]);
    this.attacks.forEach(resetAttack);
    this.currentGame = {
      id: game.id,
      combatants: [
        { ...player, attacks: this.attacks },
        {
          ...opponentState,
          attacks: await this.allAttacks.getAttacks(opponentToken.attacks),
        },
      ],
      round: BigInt(0),
      rounds: [],
      phase: "Active",
      opponentToken: game.opponent_token,
    };
  }

  endChallengeCall(caller) {
    return this.signer.getOutsideTransaction(
      callOptions(caller.address),
      this.contract.populate("end_challenge", {
        attempt_id: this.attemptId,
      })
    );
  }

  async updateGamePhase() {
    this.currentGame.phase = (
      await this.contract.game_phase(this.currentGame.id)
    ).activeVariant();
  }
}

export const runArcadeChallengeNextRounds = async (caller, challenges) => {
  const activeChallenges = challenges.filter(
    (challenge) => challenge.status === "Active"
  );
  let nextCalls = [];
  let wonGameChallenges = [];
  for (const challenge of activeChallenges.filter(
    (c) => c.currentGame.phase === "PlayerWon"
  )) {
    if (challenge.stage < 10) {
      nextCalls.push(challenge.nextStageCall(caller));
      wonGameChallenges.push(challenge);
    } else {
      nextCalls.push(challenge.endChallengeCall(caller));
      challenge.status = "PlayerWon";
    }
  }
  let lostGameChallenges = [];
  for (const challenge of activeChallenges.filter(
    (c) => c.currentGame.phase === "PlayerLost"
  )) {
    if (challenge.respawns < 2) {
      nextCalls.push(challenge.respawnCall(caller));
      lostGameChallenges.push(challenge);
    } else {
      nextCalls.push(challenge.endChallengeCall(caller));
      challenge.status = "PlayerLost";
    }
  }
  const { transaction_hash: newGamesTxHash } = await caller.executeFromOutside(
    await Promise.all(nextCalls),
    { version: 3 }
  );
  const newGameIds = (await getReturns(caller, newGamesTxHash)).map(
    (x) => x.data[0]
  );

  const newGames = Promise.all(
    newGameIds
      .splice(0, wonGameChallenges.length)
      .map((gameId, i) => wonGameChallenges[i].nextStage(gameId))
  );
  const respawnedGames = Promise.all(
    newGameIds.map((gameId, i) => lostGameChallenges[i].respawn(gameId))
  );
  await Promise.all([newGames, respawnedGames]);
  console.log("------------------------------------------------------------");
};

export const runArcadeChallengeGames = async (caller, challenges) => {
  const activeChallenges = challenges.filter(
    (challenge) => challenge.status === "Active"
  );
  const attackCalls = activeChallenges.map((challenge) => {
    return challenge.attackCall(caller);
  });
  const { transaction_hash: roundsTxHash } = await caller.executeFromOutside(
    await Promise.all(attackCalls),
    { version: 3 }
  );

  await Promise.all(activeChallenges.map((c) => c.updateGamePhase()));
  return roundsTxHash;
};

export const startArcadeChallenges = async (caller, challenges) => {
  let calls = [];
  for (const challenge of challenges) {
    calls.push(challenge.startCall(caller));
  }
  const { transaction_hash } = await caller.executeFromOutside(
    await Promise.all(calls),
    {
      version: 3,
    }
  );
  await Promise.all(
    (
      await getReturns(caller, transaction_hash)
    ).map(({ data: [attempt_id, game_id] }, i) => {
      return challenges[i].start(attempt_id, game_id);
    })
  );
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
