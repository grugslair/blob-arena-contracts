import { hash, CallData } from "starknet";
import { attackIdFromInputEntrypoint } from "../contract-defs.js";

export const attackIdFromInput = (contractAbi, input) => {
  const callData = new CallData(contractAbi);
  const attackInput = callData.compile(attackIdFromInputEntrypoint, input);
  return hash.computePoseidonHashOnElements(attackInput);
};
