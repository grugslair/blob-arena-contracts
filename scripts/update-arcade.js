import {
  loadJson,
  splitCallDescriptions,
  loadAccountManifestFromCmdArgs,
} from "./stark-utils.js";
import { CairoCustomEnum } from "starknet";
import {
  arcadeOpponentEntrypoint,
  arcadeChallengeEntrypoint,
  arcadeContractTag,
  blobertContractTag,
  freeBlobertContractTag,
  ammaBlobertContractTag,
} from "./contract-defs.js";

import { makeAttacksStruct } from "./update-attributes.js";

export const makeCollectionAddressDict = (account_manifest) => {
  return {
    blobert: account_manifest.getContractAddress(blobertContractTag),
    free_blobert: account_manifest.getContractAddress(freeBlobertContractTag),
    amma_blobert: account_manifest.getContractAddress(ammaBlobertContractTag),
  };
};

export const parseNewArcadeOpponent = (opponent, collectionAddresses) => {
  return {
    name: opponent.name,
    collection: collectionAddresses[opponent.collection],
    attributes: new CairoCustomEnum(opponent.attributes),
    stats: opponent.stats,
    attacks: makeAttacksStruct(opponent.attacks),
  };
};

export const makeArcadeOpponentsStruct = (opponents) => {
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
  return new CairoCustomEnum({ New: parseNewArcadeOpponent(opponent) });
};

export const makeCollectionsAllowed = (collections, collectionAddresses) => {
  let allowed = [];
  for (const collection of collections) {
    allowed.push(collectionAddresses[collection]);
  }
  return allowed;
};

export const makeArcadeChallengeCallData = (challenge, collectionAddresses) => {
  return {
    name: challenge.name,
    health_recovery_pc: challenge.health_recovery,
    opponents: makeArcadeOpponentsStruct(challenge.opponents),
    collections_allowed: makeCollectionsAllowed(
      challenge.collections_allowed,
      collectionAddresses
    ),
  };
};

export const makeArcadeOpponentsCalls = async (account_manifest, data) => {
  let contract = await account_manifest.getContract(arcadeContractTag);
  let collectionAddresses = makeCollectionAddressDict(account_manifest);
  let calls = [];
  for (const opponent of data) {
    calls.push([
      contract.populate(
        arcadeOpponentEntrypoint,
        parseNewArcadeOpponent(opponent, collectionAddresses)
      ),
      { description: `arcade opponent: ${opponent.name}` },
    ]);
  }
  return calls;
};

export const makeArcadeChallengeCalls = async (account_manifest, data) => {
  let contract = await account_manifest.getContract(arcadeContractTag);
  let collectionAddresses = makeCollectionAddressDict(account_manifest);
  let calls = [];
  for (const challenge of data) {
    calls.push([
      contract.populate(
        arcadeChallengeEntrypoint,
        makeArcadeChallengeCallData(challenge, collectionAddresses)
      ),
      { description: `arcade challenge: ${challenge.name}` },
    ]);
  }
  return calls;
};

const main = async () => {
  const account_manifest = await loadAccountManifestFromCmdArgs();
  let arcade_data = loadJson("../post-deploy-config/arcade.json");
  const calls_metas = [
    ...(await makeArcadeOpponentsCalls(
      account_manifest,
      arcade_data.opponents
    )),
    ...(await makeArcadeChallengeCalls(
      account_manifest,
      arcade_data.challenges
    )),
  ];
  const [calls, descriptions] = splitCallDescriptions(calls_metas);
  console.log(descriptions);
  account_manifest.execute(calls).then((res) => {
    console.log(res.transaction_hash);
  });
};

if (process.argv[1] === import.meta.filename) {
  await main();
}
