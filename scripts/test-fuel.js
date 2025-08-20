import { loadSai } from "./sai.js";

const sai = await loadSai();
sai.loadManifest();

const contract = await sai.getContract("arcade_fuel");

await sai.account.execute(
  contract.populate("set_max_fuel", { max_fuel: 100000000 })
);

// await sai.account.execute(
//   contract.populate("add_credits", { user: "0x12", amount: 100 })
// );

await sai.account.execute(
  contract.populate("withdraw", {
    user: "0x12",
    fuel_cost: 100,
    credits_cost: 100,
  })
);
