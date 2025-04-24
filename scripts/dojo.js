import { hash, num, events, CallData } from "starknet";
import { parseAbisTypes, poseidonHashString } from "./stark-utils.js";

export const eventEmittedHash = num.toHex(hash.starknetKeccak("EventEmitted"));
export const storeSetRecordHash = num.toHex(
  hash.starknetKeccak("StoreSetRecord")
);

export class DojoParser {
  constructor(abis, namespaceMappings) {
    const abi = Object.values(parseAbisTypes(abis)).concat([
      { type: "interface" },
    ]);
    this.abiEvents = events.getAbiEvents(abi);
    this.abiStructs = CallData.getAbiStruct(abi);
    this.abiEnums = CallData.getAbiEnum(abi);
    this.namespaceMappings = namespaceMappings;
  }

  parseEvents(rawEvents) {
    let dojoEvents = [];
    let dojoModels = [];
    for (const { keys, data } of rawEvents) {
      if (keys[1] in this.namespaceMappings) {
        if (keys[0] === eventEmittedHash) {
          dojoEvents.push(this.dojoEventToEvent({ keys, data }));
        } else if (keys[0] === storeSetRecordHash) {
          dojoModels.push(this.dojoModelToEvent({ keys, data }));
        }
      }
    }
    return events.parseEvents(
      [...dojoEvents, ...dojoModels],
      this.abiEvents,
      this.abiStructs,
      this.abiEnums
    );
  }
  dojoEventToEvent = (event) => {
    const {
      keys: [_, selector, system_address],
      data,
    } = event;
    const key_len = data.shift();
    return {
      block_hash: "0x1",
      block_number: "0x1",
      transaction_hash: "0x1",
      from_address: "0x1",
      keys: [this.namespaceMappings[selector], ...data.splice(0, key_len)],
      data: data.slice(1),
    };
  };
  dojoModelToEvent = (event) => {
    const {
      keys: [_, selector, entity_id],
      data,
    } = event;
    const key_len = data.shift();
    return {
      block_hash: "0x1",
      block_number: "0x1",
      transaction_hash: "0x1",
      from_address: "0x1",
      keys: [this.namespaceMappings[selector], ...data.splice(0, key_len)],
      data: data.slice(1),
    };
  };
}

export const parseDojoEvent = (event) => {
  const {
    keys: [_, selector, system_address],
    data,
  } = event;
  const key_len = data.shift();
  return {
    selector,
    system_address,
    keys: data.splice(0, key_len),
    values: data.slice(1),
  };
};
export const parseDojoSetRecord = (event) => {
  const {
    keys: [_, selector, entity_id],
    data,
  } = event;
  const key_len = data.shift();
  return {
    selector,
    entity_id,
    keys: data.splice(0, key_len),
    values: data.slice(1),
  };
};

export const parsedModelToStruct = () => {};

export const namespaceNameToHash = (namespaceName) => {
  const [namespace, name] = namespaceName.split("-");
  return hash.computePoseidonHashOnElements([
    poseidonHashString(namespace),
    poseidonHashString(name),
  ]);
};
