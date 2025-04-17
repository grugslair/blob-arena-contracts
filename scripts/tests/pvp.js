import { hash } from "starknet";
import { callOptions } from "../stark-utils.js";
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
  games
) => {
  let calls = [];
  for (const game of games) {
    const combatId = game.combat_id;
    const combatant1 = game.combatant1;
    const combatant2 = game.combatant2;
    const attack1 = randomElement(combatant1.attacks);
    const attack2 = randomElement(combatant2.attacks);
    console.log(
      `Combat ${combatId} Round ${game.round} Attacks: 0x${attack1.toString(
        16
      )} vs 0x${attack2.toString(16)}`
    );
    calls.push(
      ...combatRoundCalls(
        caller,
        account1,
        account2,
        contract,
        combatId,
        combatant1.id,
        combatant2.id,
        attack1,
        attack2
      )
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
  games
) => {
  const calls = await Promise.all(
    combatRoundsCalls(caller, account1, account2, contract, games)
  );
  await caller.executeFromOutside(calls, { version: 3 });
};

const randomElement = (array) => {
  return array[Math.floor(Math.random() * array.length)];
};
