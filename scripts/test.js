import { CairoCustomEnum } from "starknet";
import { loadSai } from "./sai.js";

const sai = await loadSai();
sai.loadManifest();

const classicToken = 0x12edn;
const ammaToken = 0x1n;

const arcadeClassicContract = await sai.getContract("arcade_classic");
const arcadeAmmaContract = await sai.getContract("arcade_amma");
const arenaCreditContract = await sai.getContract("arena_credit");
const loadoutAmmaContract = await sai.getContract("loadout_amma");
const loadoutClassicContract = await sai.getContract("loadout_classic");
const ammaBlobertContract = await sai.getContract("amma_blobert_soulbound");
const arenaBlobertContract = await sai.getContract("arena_blobert");
const ammaBlobertMinter = await sai.getContract("amma_blobert_minter");
const arenaBlobertMinter = await sai.getContract("arena_blobert_minter");

await sai.executeAndWait(
  arenaCreditContract.populate("add_credits", {
    user: sai.account.address,
    amount: 200,
  })
);
console.log("Added credits");

try {
  const maybeOwner = await ammaBlobertContract.owner_of(ammaToken);
  if (!maybeOwner) {
    throw Error("No owner");
  }
} catch (e) {
  await sai.executeAndWait(ammaBlobertMinter.populate("claim"));
  console.log("Minted Amma Blobert");
}

try {
  const maybeOwner = await arenaBlobertContract.owner_of(classicToken);
  if (!maybeOwner) {
    throw Error("No owner");
  }
} catch (e) {
  await sai.executeAndWait(arenaBlobertMinter.populate("claim_free_tokens"));
  await sai.executeAndWait(arenaBlobertMinter.populate("mint"));
  console.log("Minted Arena Blobert");
}
const ammaActionId = (
  await loadoutAmmaContract.actions(
    sai.contracts.amma_blobert_soulbound.contract_address,
    ammaToken,
    [[0]]
  )
)[0];
console.log("Amma Action ID:", ammaActionId);

const classicActionId = (
  await loadoutClassicContract.actions(
    sai.contracts.arena_blobert.contract_address,
    classicToken,
    [[1, 0]]
  )
)[0];

console.log("Classic Action ID:", classicActionId);
const classicAttemptId = (
  await sai.executeWithReturn(
    arcadeClassicContract.populate("start", {
      collection_address: sai.contracts["arena_blobert"].contract_address,
      token_id: classicToken,
      action_slots: [
        [1, 0],
        [4, 0],
        [4, 1],
        [4, 2],
      ],
    })
  )
)[0].data[0];
console.log("Classic Attempt ID:", classicAttemptId);
const ammaAttemptId = (
  await sai.executeWithReturn(
    arcadeAmmaContract.populate("start", {
      collection_address:
        sai.contracts["amma_blobert_soulbound"].contract_address,
      token_id: ammaToken,
      action_slots: [[0], [1], [2], [3]],
    })
  )
)[0].data[0];
console.log("Amma Attempt ID:", ammaAttemptId);

// await sai.executeAndWait(
//   arcadeAmmaContract.populate("act", {
//     attempt_id: ammaAttemptId,
//     action: new CairoCustomEnum({ Action: ammaActionId }),
//   })
// );

// await sai.executeAndWait(
//   arcadeClassicContract.populate("act", {
//     attempt_id: classicAttemptId,
//     action: new CairoCustomEnum({ Action: classicActionId }),
//   })
// );

let n = 1;
while (true) {
  try {
    await sai.executeAndWait(
      arcadeAmmaContract.populate("act", {
        attempt_id: ammaAttemptId,
        action: new CairoCustomEnum({ Action: ammaActionId }),
      })
    );
    console.log(`Amma action ${n} executed`);
    n++;
  } catch (e) {
    console.error("Error during amma action:");
    break;
  }
}

console.log("Amma action executed");
n = 1;
while (true) {
  try {
    await sai.executeAndWait(
      arcadeClassicContract.populate("act", {
        attempt_id: classicAttemptId,
        action: new CairoCustomEnum({ Action: classicActionId }),
      })
    );
    console.log(`Classic action ${n} executed`);
    n++;
  } catch (e) {
    console.error("Error during classic action:");
    break;
  }
}
console.log("Classic action executed");
