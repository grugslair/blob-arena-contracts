import { loadSai } from "./sai.js";

const sai = await loadSai();
sai.loadManifest();

const classicToken = 0x12edn;
const ammaToken = 0x1n;
const ammaAttackId =
  0x075e55f19968d78a969bacc2718b55d7272fde924c096f198d4da77d79b3d5c2n;
await sai.executeWithReturn(
  (await sai.getContract("arena_blobert_minter")).populate("mint")
);
await sai.executeAndWait(
  (await sai.getContract("amma_blobert_minter")).populate("claim")
);
const classicArcadeContract = await sai.getContract("classic_arcade");
const ammaArcadeContract = await sai.getContract("amma_arcade");
const classicAttackId = (
  await (
    await sai.getContract("classic_blobert_loadout")
  ).attacks(sai.contracts.arena_blobert.contract_address, classicToken, [
    [1, 0],
  ])
)[0];
const classicAttemptId = (
  await sai.executeWithReturn(
    classicArcadeContract.populate("start", {
      collection_address: sai.deployments["arena_blobert"].contract_address,
      token_id: classicToken,
      attack_slots: [
        [1, 0],
        [4, 0],
        [4, 1],
        [4, 2],
      ],
    })
  )
)[0].data[0];

const ammaAttemptId = (
  await sai.executeWithReturn(
    ammaArcadeContract.populate("start", {
      collection_address:
        sai.deployments["amma_blobert_soulbound"].contract_address,
      token_id: ammaToken,
      attack_slots: [[0], [1], [2], [3]],
    })
  )
)[0].data[0];
await sai.account.execute(
  classicArcadeContract.populate("attack", {
    attempt_id: classicAttemptId,
    attack_id: classicAttackId,
  })
);

await sai.account.execute(
  ammaArcadeContract.populate("attack", {
    attempt_id: ammaAttemptId,
    attack_id: ammaAttackId,
  })
);
