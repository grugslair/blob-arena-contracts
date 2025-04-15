import {
  loadJson,
  splitCallDescriptions,
  loadAccountManifestFromCmdArgs,
} from "./stark-utils.js";
import { CairoCustomEnum } from "starknet";

import {
  pveOpponentEntrypoint,
  pveChallengeEntrypoint,
  pveBlobertContractTag,
  blobertContractTag,
  arcadeBlobertContractTag,
  ammaBlobertContractTag,
} from "./contract-defs.js";

import { makeAttacksStruct } from "./update-attributes.js";

export const makeCollectionAddressDict = (account_manifest) => {
  return {
    blobert: account_manifest.getContractAddress(blobertContractTag),
    arcade_blobert: account_manifest.getContractAddress(
      arcadeBlobertContractTag
    ),
    amma_blobert: account_manifest.getContractAddress(ammaBlobertContractTag),
  };
};

export const parseNewPVEOpponent = (opponent, collectionAddresses) => {
  return {
    name: opponent.name,
    collection: collectionAddresses[opponent.collection],
    attributes: new CairoCustomEnum(opponent.attributes),
    stats: opponent.stats,
    attacks: makeAttacksStruct(opponent.attacks),
  };
};

export const makePveOpponentsStruct = (opponents) => {
  let opponentsStructs = [];
  for (const opponent of opponents) {
    opponentsStructs.push(parseOpponentStruct(opponent));
  }
  return opponentsStructs;
};

export const parseOpponentStruct = (opponent) => {
  if (typeof opponent.tag === "string") {
    return new CairoCustomEnum({ Tag: opponent.tag });
  }
  if (opponent.id != null) {
    return new CairoCustomEnum({ Id: opponent.id });
  }
  if (opponent.new != null) {
    return new CairoCustomEnum({ New: opponent.new });
  }
  return new CairoCustomEnum({ New: parseNewPVEOpponent(opponent) });
};

export const makeCollectionsAllowed = (collections, collectionAddresses) => {
  let allowed = [];
  for (const collection of collections) {
    allowed.push(collectionAddresses[collection]);
  }
  return allowed;
};

export const makePveChallengeCallData = (challenge, collectionAddresses) => {
  return {
    name: challenge.name,
    health_recovery_pc: challenge.health_recovery,
    opponents: makePveOpponentsStruct(challenge.opponents),
    collections_allowed: makeCollectionsAllowed(
      challenge.collections_allowed,
      collectionAddresses
    ),
  };
};

export const makePveOpponentsCalls = async (account_manifest, data) => {
  let contract = await account_manifest.getContract(pveBlobertContractTag);
  let collectionAddresses = makeCollectionAddressDict(account_manifest);
  let calls = [];
  for (const opponent of data) {
    calls.push([
      contract.populate(
        pveOpponentEntrypoint,
        parseNewPVEOpponent(opponent, collectionAddresses)
      ),
      { description: `pve opponent: ${opponent.name}` },
    ]);
  }
  return calls;
};

export const makePveChallengeCalls = async (account_manifest, data) => {
  let contract = await account_manifest.getContract(pveBlobertContractTag);
  let collectionAddresses = makeCollectionAddressDict(account_manifest);
  let calls = [];
  for (const challenge of data) {
    calls.push([
      contract.populate(
        pveChallengeEntrypoint,
        makePveChallengeCallData(challenge, collectionAddresses)
      ),
      { description: `pve challenge: ${challenge.name}` },
    ]);
  }
  return calls;
};

const main = async () => {
  const account_manifest = await loadAccountManifestFromCmdArgs();
  let pve_data = loadJson("../post-deploy-config/pve.json");
  const calls_metas = [
    ...(await makePveOpponentsCalls(account_manifest, pve_data.opponents)),
    ...(await makePveChallengeCalls(account_manifest, pve_data.challenges)),
  ];
  const [calls, descriptions] = splitCallDescriptions(calls_metas);
  console.log(descriptions);
  const transaction_hash = await account_manifest.execute(calls);
  console.log(transaction_hash);
};

if (process.argv[1] === import.meta.filename) {
  await main();
}
