import { loadSai } from "./sai.js";

const deployWithOwner = [
  "amma_blobert",
  "arena_blobert",
  "attack",
  "classic_arcade",
];

const sai = await loadSai();
await sai.declareAllClasses();
const deploysData1 = [];
for (const name of deployWithOwner) {
  deploysData1.push({
    tag: name,
    class: name,
    salt: "0x0",
    unique: false,
    calldata: [sai.account.address],
  });
}
await sai.deployContract(deploysData1);
const deploysData2 = [
  {
    tag: "amma_blobert_loadout",
    class: "amma_blobert_loadout",
    salt: "0x0",
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
    salt: "0x0",
    unique: false,
    calldata: {
      owner: sai.account.address,
      attack_dispatcher_address: sai.deployments["attack"].contract_address,
      collection_addresses: [sai.deployments["amma_blobert"].contract_address],
    },
  },
];
await sai.deployContract(deploysData2);
const calls = [];
for (const contract_tag in sai.deployments) {
  const contract = await sai.getContract(contract_tag);
  console.log(contract);
  calls.push(
    contract.populate("grant_contract_writer", { writer: sai.account.address })
  );
}
const attack_contract = await sai.getContract("attack");
attack_contract.populate("grant_contract_writers", {
  writers: [
    sai.deployments["amma_blobert_loadout"].contract_address,
    sai.deployments["arena_blobert_loadout"].contract_address,
  ],
});

sai.dumpJson();
