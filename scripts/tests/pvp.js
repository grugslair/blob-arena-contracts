import { hash } from "starknet";

const commitAttack = async (account, contract, combatantId, commitment) => {
  const { transaction_hash } = await account.execute(
    contract.populate("commit", {
      combatant_id: combatantId,
      hash: commitment,
    }),
    contract.abi,
    {
      version: 3,
    }
  );
  return transaction_hash;
};

const revealAttack = async (account, contract, combatantId, attack, salt) => {
  const { transaction_hash } = await account.execute(
    contract.populate("reveal", {
      combatant_id: combatantId,
      attack,
      salt,
    }),
    contract.abi,
    {
      version: 3,
    }
  );
  return transaction_hash;
};

const runRound = async (account, contract, combatId) => {
  await account.execute(
    contract.populate("run", {
      combat_id: combatId,
    }),
    contract.abi,
    {
      version: 3,
    }
  );
};

export const runCombatRound = async (
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

  const commitTransactionHash1 = await commitAttack(
    account1,
    contract,
    combatant1,
    commitment1
  );
  const commitTransactionHash2 = await commitAttack(
    account2,
    contract,
    combatant2,
    commitment2
  );
  let revealTransactionHash1;
  let revealTransactionHash2;
  try {
    revealTransactionHash1 = await revealAttack(
      account1,
      contract,
      combatant1,
      attack1,
      salt1
    );
    revealTransactionHash2 = await revealAttack(
      account2,
      contract,
      combatant2,
      attack2,
      salt2
    );
  } catch (e) {
    await account1.waitForTransaction(commitTransactionHash1);
    await account2.waitForTransaction(commitTransactionHash2);
    revealTransactionHash1 = await revealAttack(
      account1,
      contract,
      combatant1,
      attack1,
      salt1
    );
    revealTransactionHash2 = await revealAttack(
      account2,
      contract,
      combatant2,
      attack2,
      salt2
    );
  }
  try {
    await runRound(account1, contract, combatId);
  } catch (e) {
    await account1.waitForTransaction(revealTransactionHash1);
    await account2.waitForTransaction(revealTransactionHash2);
    await runRound(account1, contract, combatId);
  }
};

export const runBattle = async (
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

const randomElement = (array) => {
  return array[Math.floor(Math.random() * array.length)];
};
