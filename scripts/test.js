import { loadSai } from "./sai.js";

const sai = await loadSai();
sai.loadManifest();

const token =
  0x00000000000000000000000000000000000000000000000000000000000012edn;
const attempt_id =
  0x11726db434fbf5c6904659f20e93f8508236258a77564dd24d88db262ca534an;
const attack_id =
  0x07bd8bf3b93307872158ee00eb2d6cda7824d0d43a80978b13ec9052eeca27ecn;

await sai.account.execute(
  (await sai.getContract("arena_blobert_minter")).populate("mint")
);

await sai.account.execute(
  (
    await sai.getContract("classic_arcade")
  ).populate("start", {
    collection_address: sai.deployments["arena_blobert"].contract_address,
    token_id: token,
    attack_slots: [
      [1, 0],
      [4, 0],
      [4, 1],
      [4, 2],
    ],
  })
);

await sai.account.execute(
  (
    await sai.getContract("classic_arcade")
  ).populate("attack", { attempt_id, attack_id })
);
