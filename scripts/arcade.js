import { parseU8, parsePercentToPpm, parseU32 } from "./loadout.js";

const parseDropRates = (rates) => {
  return {
    common_full: parsePercentToPpm(rates.common_full || 0, "common_full"),
    rare_full: parsePercentToPpm(rates.rare_full || 0, "rare_full"),
    epic_full: parsePercentToPpm(rates.epic_full || 0, "epic_full"),
    legendary_full: parsePercentToPpm(
      rates.legendary_full || 0,
      "legendary_full"
    ),
    rare_shard: parsePercentToPpm(rates.rare_shard || 0, "rare_shard"),
    epic_shard: parsePercentToPpm(rates.epic_shard || 0, "epic_shard"),
    legendary_shard: parsePercentToPpm(
      rates.legendary_shard || 0,
      "legendary_shard"
    ),
    max_rare_shards: parseU8(rates.max_rare_shards, "max_rare_shards"),
    max_epic_shards: parseU8(rates.max_epic_shards, "max_epic_shards"),
    max_legendary_shards: parseU8(
      rates.max_legendary_shards,
      "max_legendary_shards"
    ),
  };
};

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
    contract.populate("set_orb_minter_address", {
      contract_address: sai.contracts.orb_minter.contract_address,
    }),
    contract.populate("set_max_orb_uses", {
      max_uses: parseU32(config.max_orb_uses, "max_orb_uses"),
    }),
    contract.populate("set_drop_rates", {
      challenge_rates: parseDropRates(config.challenge_drop_rates),
      stage_rates: config.stage_drop_rates.map(parseDropRates),
    }),
  ];
};
