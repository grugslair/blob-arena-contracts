import { loadSai } from "./sai.js";
import { makeArenaBlobertCalls } from "./set-arena-token.js";
import { makeClassicArcadeCalls } from "./set-classic-arcade.js";
import { makeBlobertLoadouts } from "./set-classic-loadout.js";

const deployWithOwner = ["amma_blobert", "arena_blobert", "attack"];

const salt = 0x123456789;

const sai = await loadSai();
await sai.declareAllClasses();
const deploysData1 = [];
for (const name of deployWithOwner) {
  deploysData1.push({
    tag: name,
    class: name,
    salt,
    unique: false,
    calldata: [sai.account.address],
  });
}
await sai.deployContract(deploysData1);

const deploysData2 = [
  {
    tag: "arena_blobert_minter",
    class: "arena_blobert_minter",
    salt,
    unique: false,
    calldata: {
      owner: sai.account.address,
      token_address: sai.deployments["arena_blobert"].contract_address,
    },
  },
  {
    tag: "amma_blobert_loadout",
    class: "amma_blobert_loadout",
    salt,
    unique: false,
    calldata: {
      owner: sai.account.address,
      attack_dispatcher_address: sai.deployments["attack"].contract_address,
      collection_address: sai.deployments["amma_blobert"].contract_address,
    },
  },
  {
    tag: "arena_blobert_loadout",
    class: "arena_blobert_loadout",
    salt,
    unique: false,
    calldata: {
      owner: sai.account.address,
      attack_dispatcher_address: sai.deployments["attack"].contract_address,
      collection_addresses: [
        sai.deployments["arena_blobert"].contract_address,
        sai.contracts["blobert"].contract_address,
      ],
    },
  },
];
await sai.deployContract(deploysData2);
await sai.deployContract({
  tag: "classic_arcade",
  class: "classic_arcade",
  salt,
  unique: false,
  calldata: {
    owner: sai.account.address,
    attack_contract: sai.deployments["attack"].contract_address,
    loadout_contract: sai.deployments["arena_blobert_loadout"].contract_address,
  },
});
const calls = [];
for (const contract_tag in sai.deployments) {
  const contract = await sai.getContract(contract_tag);
  calls.push(
    contract.populate("grant_contract_writer", { writer: sai.account.address })
  );
}
calls.push(
  (await sai.getContract("arena_blobert")).populate("grant_contract_writer", {
    writer: sai.deployments["arena_blobert_minter"].contract_address,
  })
);
calls.push(
  (await sai.getContract("attack")).populate("grant_contract_writers", {
    writers: [
      sai.deployments["amma_blobert_loadout"].contract_address,
      sai.deployments["arena_blobert_loadout"].contract_address,
    ],
  })
);
await sai.executeAndWait(calls);
await sai.executeAndWait(await makeBlobertLoadouts(sai));
await sai.executeAndWait([
  ...(await makeClassicArcadeCalls(sai)),
  ...(await makeArenaBlobertCalls(sai)),
]);

sai.dumpJson();
