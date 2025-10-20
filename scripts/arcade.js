export const makeArcadeConfigCalls = (sai, contract, config) => {
  return [
    contract.populate("set_max_respawns", {
      max_respawns: BigInt(config.max_respawns),
    }),
    contract.populate("set_time_limit", {
      time_limit: BigInt(config.time_limit),
    }),
    contract.populate("set_health_regen_percent", {
      health_regen_percent: BigInt(config.health_regen_percent),
    }),
    contract.populate("set_cost", {
      energy: BigInt(config.energy_cost),
      credit: BigInt(config.credit_cost),
    }),
    contract.populate("set_vrf_address", {
      contract_address: sai.contracts.vrf.contract_address,
    }),
    contract.populate("set_credit_address", {
      contract_address: sai.contracts.arena_credit.contract_address,
    }),
  ];
};
