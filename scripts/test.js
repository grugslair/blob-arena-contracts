import { CallData, EntryPointType } from "starknet";
import { loadSai } from "./sai.js";

const sai = await loadSai();
sai.loadManifest();

const classicToken = 0x12edn;
const ammaToken = 0x1n;
const ammaAttackId =
  0x075e55f19968d78a969bacc2718b55d7272fde924c096f198d4da77d79b3d5c2n;

const arcadeClassicContract = await sai.getContract("arcade_classic");
const arcadeAmmaContract = await sai.getContract("arcade_amma");
const purchaseContract = await sai.getContract("arena_credit_purchase");
const starkContract = await sai.getContract("stark_token");

// console.log(starkContract);
// console.log({
//   spender: purchaseContract.address,
//   amount: 1_000_000_000_000_000_000_000_000_000n,
// });

// console.log(
//   starkContract.populate("approve", {
//     spender: purchaseContract.address,
//     amount: 1_000_000_000_000_000_000_000_000_000n,
//   })
// );
console.log({
  contractAddress: starkContract.address,
  entrypoint: "approve",
  calldata: CallData.compile([
    purchaseContract.address,
    1_000_000_000_000_000_000_000_000_000n,
    0,
  ]),
});
await sai.executeAndWait([
  {
    contractAddress: starkContract.address,
    entrypoint: "approve",
    calldata: CallData.compile([
      purchaseContract.address,
      1_000_000_000_000_000_000_000_000_000n,
      0,
    ]),
  },
]);

await sai.executeAndWait(
  purchaseContract.populate("purchase", {
    erc20_address: starkContract.address,
    receiver: 0x0,
    amount: 200,
  })
);

// await sai.executeWithReturn(
//   (await sai.getContract("arena_blobert_minter")).populate("mint")
// );
// await sai.executeAndWait(
//   (await sai.getContract("amma_blobert_minter")).populate("claim")
// );

// const classicAttackId = (
//   await (
//     await sai.getContract("loadout_classic")
//   ).attacks(sai.contracts.arena_blobert.contract_address, classicToken, [
//     [1, 0],
//   ])
// )[0];
// const classicAttemptId = (
//   await sai.executeWithReturn(
//     arcadeClassicContract.populate("start", {
//       collection_address: sai.contracts["arena_blobert"].contract_address,
//       token_id: classicToken,
//       attack_slots: [
//         [1, 0],
//         [4, 0],
//         [4, 1],
//         [4, 2],
//       ],
//     })
//   )
// )[0].data[0];

// const ammaAttemptId = (
//   await sai.executeWithReturn(
//     arcadeAmmaContract.populate("start", {
//       collection_address:
//         sai.contracts["amma_blobert_soulbound"].contract_address,
//       token_id: ammaToken,
//       attack_slots: [[0], [1], [2], [3]],
//     })
//   )
// )[0].data[0];
// await sai.account.execute(
//   arcadeClassicContract.populate("attack", {
//     attempt_id: classicAttemptId,
//     attack_id: classicAttackId,
//   })
// );

// await sai.account.execute(
//   arcadeAmmaContract.populate("attack", {
//     attempt_id: ammaAttemptId,
//     attack_id: ammaAttackId,
//   })
// );
