export const makeSetCombatClassHashCall = (contract, classHash) => {
  return contract.populate("set_combat_class_hash", { class_hash: classHash });
};
