import { loadSai } from "./sai.js";
import { selector } from "starknet";
const sai = await loadSai();
sai.loadManifest();
const grantOwnerSelector = selector.getSelector("GrantContractOwner"); // 0x14d600693def062f67e727517605ba2b9a4acbc44deecc0a9b2b25cc2abee08
const revokeOwnerSelector = selector.getSelector("RevokeContractOwner"); // 0x14f852a9e2a25e2cd101582cd0ca9f9904d36bf7ab5e8e07da20c57c2e6590d
const grantWriterSelector = selector.getSelector("GrantContractWriter"); // 0x1042574016370d3278e2015c3d44515159afa8ad199ddec95bdd4c6222a41b0
const revokeWriterSelector = selector.getSelector("RevokeContractWriter"); // 0x2cb500e28aa81a0df3d7e3993fbef9a3468045dcc9e7e888cec7f8864c7e8cb

console.log("Grant Owner Selector:", grantOwnerSelector);
console.log("Revoke Owner Selector:", revokeOwnerSelector);
console.log("Grant Writer Selector:", grantWriterSelector);
console.log("Revoke Writer Selector:", revokeWriterSelector);
// let permission = await sai.getWriters([
//   sai.contracts.arena_blobert.contract_address,
//   sai.contracts.amma_blobert.contract_address,
// ]);
// console.log(permission);
// let events = await sai.account.getEvents({
//   address: sai.contracts.arena_blobert.contract_address,
//   keys: [[grantWriterSelector, revokeWriterSelector]],
//   chunk_size: 1000,
// });
// const hasPermission = {};
// for (const {
//   keys: [id, contract_address],
// } of events.events) {
//   if (id === grantWriterSelector) {
//     hasPermission[contract_address] = true;
//   } else if (id === revokeWriterSelector) {
//     hasPermission[contract_address] = false;
//   }
// }
let calls = await sai.setOnlyWritersCalls({ arena_blobert: ["0x0"] });
console.log("Calls:", calls);
// const getGrantRevokeCalls = (current, desired) => {
//   const desired_set = new Set(desired);
//   const current_set = new Set(current);
//   let toGrant = desired_set.difference(current_set);
//   let toRevoke = current_set.difference(desired_set);
//   return { toGrant, toRevoke };
// };

// const { toGrant, toRevoke } = getGrantRevokeCalls([1, 2, 3], [2, 3, 4]);
// console.log("To Grant:", toGrant);
// console.log("To Revoke:", toRevoke);
