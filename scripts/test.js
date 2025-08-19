import { loadSai } from "./sai.js";

const sai = await loadSai();
sai.loadManifest();

const classicToken = 0x12edn;
const ammaToken = 0x1n;
const ammaAttack =
  0x075e55f19968d78a969bacc2718b55d7272fde924c096f198d4da77d79b3d5c2n;
await sai.executeWithReturn(
  (await sai.getContract("arena_blobert_minter")).populate("mint")
);
await sai.executeWithReturn(
  (await sai.getContract("amma_blobert_minter")).populate("claim")
);

const classicAttackId = (
  await sai.getContract("classic_blobert_loadout")
).attacks(sai.contracts.arena_blobert.contract_address, classicToken, [
  [1, 0],
])[0];

const classicAttemptId = (
  await sai.executeWithReturn(
    (
      await sai.getContract("classic_arcade")
    ).populate("start", {
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
    (
      await sai.getContract("amma_arcade")
    ).populate("start", {
      collection_address:
        sai.deployments["amma_blobert_soulbound"].contract_address,
      token_id: ammaToken,
      attack_slots: [[0], [1], [2], [3]],
    })
  )
)[0].data[0];

await sai.account.execute(
  (
    await sai.getContract("classic_arcade")
  ).populate("attack", { classicAttemptId, attack_id: classicAttackId })
);

await sai.account.execute(
  (
    await sai.getContract("classic_arcade")
  ).populate("attack", { ammaAttemptId, attack_id: ammaAttack })
);
