import { callOptions, getReturns } from "../stark-utils.js";
import { randomElement } from "../utils.js";

export const runArcadeGameCall = (caller, signer, contract, challenge) => {
  return signer.getOutsideTransaction(
    callOptions(caller.address),
    contract.populate("attack", {
      game_id: challenge.game.id,
      attack_id: randomElement(challenge.token.attacks),
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

export const runArcadeChallengeGames = async (
  caller,
  signer,
  contract,
  challenges
) => {
  let calls = [];
  let activeChallenges = [];
  for (let i = 0; i < challenges.length; i++) {
    const challenge = challenges[i];
    if (challenge.status === "Active") {
      activeChallenges.push(challenge);
      challenge.game.round++;
      calls.push(runArcadeGameCall(caller, signer, contract, challenge));
    }
  }
  await caller.executeFromOutside(await Promise.all(calls), {
    version: 3,
  });
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
  const { transaction_hash } = await caller.executeFromOutside(
    await Promise.all(calls),
    {
      version: 3,
    }
  );
  const newGames = (await getReturns(caller, transaction_hash)).map(
    (x) => x.data[0]
  );
  for (let i = 0; i < newGameChallenges.length; i++) {
    const challenge = newGameChallenges[i];
    challenge.games.push(challenge.game);
    challenge.game = {
      id: newGames[i],
      round: 0,
      results: [],
    };
  }
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
  for (const token of tokens) {
    calls.push(
      startArcadeChallengeCall(
        caller,
        signer,
        contract,
        challengeId,
        token.collection_address,
        token.id,
        token.attack_slots
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
  let attempts = [];
  for (let i = 0; i < tokens.length; i++) {
    const [attempt_id, game_id] = returns[i].data;
    attempts.push({
      token: tokens[i],
      challenge_id: challengeId,
      attempt_id,
      respawns: 0,
      stage: 1,
      status: "Active",
      game: { id: game_id, results: [], round: 0 },
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
