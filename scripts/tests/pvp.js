import { hash, events, num } from "starknet";
import { callOptions } from "../stark-utils.js";
import { randomUseableAttack } from "./attacks.js";
import {
  eventEmittedHash,
  namespaceNameToHash,
  storeSetRecordHash,
  DojoParser,
} from "../dojo.js";
const { toHex } = num;

const roundResultHash = namespaceNameToHash("blob_arena-RoundResult");
const combatantStateHash = namespaceNameToHash("blob_arena-CombatantState");
const dojoNamespaceMap = {
  [roundResultHash]: num.toHex(hash.starknetKeccak("RoundResult")),
  [combatantStateHash]: num.toHex(hash.starknetKeccak("CombatantState")),
};

const roundResultPath = "blob_arena::attacks::results::RoundResult";
const combatantStatePath = "blob_arena::combatants::components::CombatantState";
const commitAttackCall = (contract, combatantId, commitment) => {
  return contract.populate("commit", {
    combatant_id: combatantId,
    hash: commitment,
  });
};

const revealAttackCall = (contract, combatantId, attack, salt) => {
  return contract.populate("reveal", {
    combatant_id: combatantId,
    attack,
    salt,
  });
};

const runRoundCall = (contract, combatId) => {
  return contract.populate("run", {
    combat_id: BigInt(combatId),
  });
};

export const runCombatRound = async (
  caller,
  account1,
  account2,
  contract,
  combatId,
  combatant1,
  combatant2,
  attack1,
  attack2
) => {
  const calls = await Promise.all(
    combatRoundCalls(
      caller,
      account1,
      account2,
      contract,
      combatId,
      combatant1,
      combatant2,
      attack1,
      attack2
    )
  );
  await caller.executeFromOutside(calls, { version: 3 });
};

export const combatRoundCalls = (
  caller,
  account1,
  account2,
  contract,
  combatId,
  combatant1,
  combatant2,
  attack1,
  attack2
) => {
  const array1 = new Uint8Array(31);
  const array2 = new Uint8Array(31);
  crypto.getRandomValues(array1);
  crypto.getRandomValues(array2);
  const salt1 = BigInt(
    "0x" +
      Array.from(array1)
        .map((b) => b.toString(16).padStart(2, "0"))
        .join("")
  );
  const salt2 = BigInt(
    "0x" +
      Array.from(array2)
        .map((b) => b.toString(16).padStart(2, "0"))
        .join("")
  );
  const commitment1 = hash.computePoseidonHashOnElements([attack1, salt1]);
  const commitment2 = hash.computePoseidonHashOnElements([attack2, salt2]);
  const commit1 = account1.getOutsideTransaction(
    callOptions(caller.address),
    commitAttackCall(contract, combatant1, commitment1)
  );
  const commit2 = account2.getOutsideTransaction(
    callOptions(caller.address),
    commitAttackCall(contract, combatant2, commitment2)
  );
  const reveal1 = account1.getOutsideTransaction(
    callOptions(caller.address),
    revealAttackCall(contract, combatant1, attack1, salt1)
  );
  const reveal2 = account2.getOutsideTransaction(
    callOptions(caller.address),
    revealAttackCall(contract, combatant2, attack2, salt2)
  );
  const runRound = account1.getOutsideTransaction(
    callOptions(caller.address),
    runRoundCall(contract, combatId)
  );
  return [commit1, commit2, reveal1, reveal2, runRound];
};

export const combatRoundsCalls = (
  caller,
  account1,
  account2,
  contract,
  games,
  attacks
) => {
  let calls = [];

  for (const game of games) {
    const combatId = game.combat_id;
    const combatant1 = game.combatant1;
    const combatant2 = game.combatant2;
    const attack1Id = randomUseableAttack(
      attacks,
      combatant1.attacks,
      game.round
    );

    const attack2Id = randomUseableAttack(
      attacks,
      combatant2.attacks,
      game.round
    );
    combatant1.attacks[attack1Id] = BigInt(game.round);
    combatant2.attacks[attack2Id] = BigInt(game.round);
    calls.push(
      ...combatRoundCalls(
        caller,
        account1,
        account2,
        contract,
        combatId,
        combatant1.id,
        combatant2.id,
        attack1Id,
        attack2Id
      )
    );
    const attack1Name = attacks[attack1Id].name;
    const attack2Name = attacks[attack2Id].name;

    console.log(
      `Game ${game.n}: round: ${game.round} ${attack1Name} vs ${attack2Name}`
    );
  }

  return calls;
};

export const runBattle = async (
  caller,
  account1,
  account2,
  contract,
  gameId,
  combatant1,
  combatant2
) => {
  let n = 1;
  while ((await contract.combat_phase(gameId)).activeVariant() === "Commit") {
    const attack1 = randomElement(combatant1.attacks);
    const attack2 = randomElement(combatant2.attacks);
    console.log(
      `Round ${n} Attacks: 0x${attack1.toString(16)} vs 0x${attack2.toString(
        16
      )}`
    );
    await runCombatRound(
      caller,
      account1,
      account2,
      contract,
      gameId,
      combatant1.combatant_id,
      combatant2.combatant_id,
      attack1,
      attack2
    );
    n++;
  }
};

export const runRounds = async (
  caller,
  account1,
  account2,
  contract,
  games,
  attacks
) => {
  const calls = await Promise.all(
    combatRoundsCalls(caller, account1, account2, contract, games, attacks)
  );
  const { transaction_hash } = await caller.executeFromOutside(calls, {
    version: 3,
  });
  return transaction_hash;
};

export const runPvpBattles = async (
  world,
  caller,
  account1,
  account2,
  contract,
  games,
  attacks
) => {
  const maxRunningGames = 9;
  let eventCalls = [];
  const dojoParser = new DojoParser(contract.abi, dojoNamespaceMap);
  while (games.filter((game) => game.winner === null).length) {
    const runningGames = games
      .filter((game) => game.winner === null)
      .slice(0, maxRunningGames);

    const transaction_hash = await runRounds(
      caller,
      account1,
      account2,
      contract,
      runningGames,
      attacks
    );
    for (const game of runningGames) {
      const phase = await contract.combat_phase(game.combat_id);
      if (phase.activeVariant() !== "Commit") {
        game.winner = phase.unwrap();
      }
    }
    for (const game of runningGames) {
      game.round++;
    }
    eventCalls.push(
      caller
        .waitForTransaction(transaction_hash)
        .then(({ events }) => dojoParser.parseEvents(events))
    );
  }
  let combatants = {};
  let results = {};
  games.map(({ combat_id, combatant1, combatant2 }) => {
    combatants[combatant1.id] = [combat_id, 1];
    combatants[combatant2.id] = [combat_id, 2];
    results[combat_id] = [];
  });
  const rounds = await Promise.all(eventCalls);
  for (const round of rounds) {
    let roundEvents = {};
    for (const event of round) {
      if (roundResultPath in event) {
        const { combat_id, attacks: _attacks } = event[roundResultPath];
        if (!(combat_id in roundEvents)) {
          roundEvents[combat_id] = { 1: {}, 2: {} };
        }
        for (let i = 0; i < _attacks.length; i++) {
          const { combatant_id, attack, result } = _attacks[i];
          const [gameId, index] = combatants[combatant_id];

          Object.assign(roundEvents[combat_id][index.toString()], {
            order: i,
            attack: attacks[attack],
            result,
          });
        }
      } else if (combatantStatePath in event) {
        const { id, health, stun_chance, stats } = event[combatantStatePath];
        const [combat_id, index] = combatants[id];
        if (!(combat_id in roundEvents)) {
          roundEvents[combat_id] = { 1: {}, 2: {} };
        }
        Object.assign(roundEvents[combat_id][index.toString()], {
          id,
          health,
          stun_chance,
          stats,
          index,
        });
      }
    }

    for (const [combat_id, result] of Object.entries(roundEvents)) {
      results[combat_id].push([result["1"], result["2"]]);
    }
  }
  for (const game of games) {
    game.results = results[game.combat_id];
  }
};
