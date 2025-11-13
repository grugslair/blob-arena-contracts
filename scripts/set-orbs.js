import { loadJson } from "./stark-utils.js";
import { loadSai } from "./sai.js";
import { parseNewAction } from "./loadout.js";
import { CairoCustomEnum } from "starknet";
import { pascalCase } from "pascal-case";

const parseNewActionsAndIds = (actions, check) => {
  return [actions.filter((_, i) => check[i][1]), check.map(([id, _]) => id)];
};

const makeOrbActionsCalls = async (
  sai,
  orbContract,
  commonActionInputs,
  rareActionInputs,
  epicActionInputs,
  legendaryActionInputs
) => {
  const commonActions = (commonActionInputs || []).map(parseNewAction);
  const rareActions = (rareActionInputs || []).map(parseNewAction);
  const epicActions = (epicActionInputs || []).map(parseNewAction);
  const legendaryActions = (legendaryActionInputs || []).map(parseNewAction);
  const actionContract = await sai.getContract("action");
  let [commonCheck, rareCheck, epicCheck, legendaryCheck] =
    await actionContract.check_action_arrays([
      commonActions,
      rareActions,
      epicActions,
      legendaryActions,
    ]);
  const [newCommon, commonIds] = parseNewActionsAndIds(
    commonActions,
    commonCheck
  );
  const [newRare, rareIds] = parseNewActionsAndIds(rareActions, rareCheck);
  const [newEpic, epicIds] = parseNewActionsAndIds(epicActions, epicCheck);
  const [newLegendary, legendaryIds] = parseNewActionsAndIds(
    legendaryActions,
    legendaryCheck
  );
  return [
    actionContract.populate("create_actions", {
      actions: [...newCommon, ...newRare, ...newEpic, ...newLegendary],
    }),
    orbContract.populate("set_common_actions", { actions: commonIds }),
    orbContract.populate("set_rare_actions", { actions: rareIds }),
    orbContract.populate("set_epic_actions", { actions: epicIds }),
    orbContract.populate("set_legendary_actions", { actions: legendaryIds }),
  ];
};

export const makeOrbTokenCalls = async (sai) => {
  const contract = await sai.getContract("orb");
  return [
    contract.populate("grant_role", {
      user: sai.contracts.arcade_amma.contract_address,
      role: new CairoCustomEnum({ Consumer: {} }),
    }),
    contract.populate("grant_role", {
      user: sai.contracts.arcade_classic.contract_address,
      role: new CairoCustomEnum({ Consumer: {} }),
    }),
  ];
};

export const makeOrbPermissionsCalls = async (sai) => {
  const contract = await sai.getContract("orb");
  const calls = [
    contract.populate("grant_role", {
      user: sai.contracts.orb_minter.contract_address,
      role: new CairoCustomEnum({ Minter: {} }),
    }),
    contract.populate("grant_role", {
      user: sai.contracts.arcade_amma.contract_address,
      role: new CairoCustomEnum({ Consumer: {} }),
    }),
    contract.populate("grant_role", {
      user: sai.contracts.arcade_classic.contract_address,
      role: new CairoCustomEnum({ Consumer: {} }),
    }),
    contract.populate("grant_role", {
      user: sai.contracts.pvp.contract_address,
      role: new CairoCustomEnum({ Consumer: {} }),
    }),
  ];
  return calls;
};

export const makeOrbsMinterConfigCalls = async (sai) => {
  const data = loadJson("./post-deploy-config/orbs.json");
  const contract = await sai.getContract("orb_minter");
  return [
    contract.populate("set_shards_in_orbs", data.shards_in_orbs),
    contract.populate("set_charge", { charge: data.charge }),
    ...(await makeOrbActionsCalls(
      sai,
      contract,
      data.common_actions,
      data.rare_actions,
      data.epic_actions,
      data.legendary_actions
    )),
  ];
};

const main = async () => {
  const sai = await loadSai();
  sai.loadManifest();
  await sai.account.execute(await makeOrbsMinterConfigCalls(sai));
};

if (process.argv[1] === import.meta.filename) {
  await main();
}
