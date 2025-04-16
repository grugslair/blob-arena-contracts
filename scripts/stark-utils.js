import {
  Contract,
  CairoCustomEnum,
  Account,
  cairo,
  RPC,
  stark,
  ec,
  hash,
  CallData,
} from "starknet";
import { fileURLToPath } from "url";
import { dirname } from "path";
import commandLineArgs from "command-line-args";
import * as fs from "fs";
import * as path from "path";
import * as accounts from "web3-eth-accounts";
import * as toml from "toml";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const returnKey =
  "0x17c9a55536e844e86b35cd70d23a4e304a30e5e08de591b6788319186160f50";

export const loadJson = (path) => {
  return JSON.parse(fs.readFileSync(resolvePath(path)));
};

export const loadToml = (path) => {
  return toml.parse(fs.readFileSync(resolvePath(path)));
};

export const resolvePath = (rpath) => {
  return path.resolve(__dirname, rpath);
};

export const getContractAddress = (mainfest, contractName) => {
  for (const contract of mainfest.contracts) {
    if (contract.tag === contractName) {
      return contract.address;
    }
  }
  return null;
};

export const readKeystorePK = async (
  keystorePath,
  accountAddress,
  password
) => {
  let data = loadJson(keystorePath);
  data.address = accountAddress;
  return (await accounts.decrypt(data, password)).privateKey;
};

export const getContract = async (provider, contractAddress) => {
  const { abi: abi } = await provider.getClassAt(contractAddress);
  return new Contract(abi, contractAddress, provider);
};

export const makeCairoEnum = (option) => {
  let [key, value] = parseEnumObject(option);
  return new CairoCustomEnum({ [key]: value });
};

export const parseEnumObject = (obj) => {
  if (["string"].includes(typeof obj)) {
    return [obj, {}];
  } else {
    for (const o in obj) {
      return [o, obj[o]];
    }
  }
};

export const makeCall = (contract, entrypoint, calldata) => {
  return contract.populate(entrypoint, calldata);
};

export class AccountManifest {
  constructor(dojo_toml_path, manifest_path, profile) {
    this.dojo_toml = loadToml(dojo_toml_path);
    this.manifest = loadJson(manifest_path);
    this.rpc_url = this.dojo_toml.env.rpc_url;
    this.profile = profile;
    if (this.dojo_toml.env.private_key) {
      this.account = new Account(
        { nodeUrl: this.rpc_url },
        this.dojo_toml.env.account_address,
        this.dojo_toml.env.private_key
      );
    }
    this.contracts = {};
  }

  async init_keystore(password) {
    const privateKey = await readKeystorePK(
      await resolvePath(this.dojo_toml.env.keystore_path),
      this.dojo_toml.env.account_address,
      password
    );
    this.account = new Account(
      { nodeUrl: this.dojo_toml.env.rpc_url },
      this.dojo_toml.env.account_address,
      privateKey
    );
  }

  async getContract(tag) {
    if (this.contracts[tag]) {
      return this.contracts[tag];
    } else {
      const address = this.getContractAddress(tag);
      if (address) {
        this.contracts[tag] = await getContract(this.account, address);
        return this.contracts[tag];
      } else {
        throw new Error(`Contract ${tag} not found in manifest`);
      }
    }
  }
  getContractAddress(tag) {
    return getContractAddress(this.manifest, tag);
  }
  async execute(calls) {
    const { transaction_hash } = await this.account.execute(calls, {
      version: 3,
    });
    await this.account.waitForTransaction(transaction_hash, {
      retryInterval: 100,
      successStates: [
        RPC.ETransactionStatus.RECEIVED,
        RPC.ETransactionExecutionStatus.SUCCEEDED,
        RPC.ETransactionStatus.ACCEPTED_ON_L2,
        RPC.ETransactionStatus.ACCEPTED_ON_L1,
      ],
    });
    return transaction_hash;
  }
}

export const batchCalls = (calls, batchSize) => {
  const chunks = [];
  for (let i = 0; i < calls.length; i += batchSize) {
    chunks.push(calls.slice(i, i + batchSize));
  }
  return chunks;
};

export const splitCallDescriptions = (calls_metas) => {
  const descriptions = [];
  const calls = [];
  for (const [call, meta] of calls_metas) {
    descriptions.push(meta.description);
    calls.push(call);
  }
  return [calls, descriptions];
};

export const loadAccountManifest = async (profile, password = null) => {
  const account_manifest = new AccountManifest(
    `../dojo_${profile}.toml`,
    `../manifest_${profile}.json`,
    profile
  );
  if (password) {
    await account_manifest.init_keystore(password);
  } else if (account_manifest.dojo_toml.env.keystore_path) {
    throw new Error(
      `Keystore path is set, but no password provided. Please provide a password.`
    );
  }
  return account_manifest;
};

export const deployContract = async (
  account,
  classHash,
  callData,
  salt,
  unique
) => {
  const deployResponse = await account.deployContract(
    { classHash, salt, unique, constructorCalldata: callData },
    { version: 3 }
  );
  await account.waitForTransaction(deployResponse.transaction_hash);
  console.log(
    `Deployed contract with class Hash: ${classHash} and address: ${deployResponse.contract_address}`
  );
  return {
    salt,
    unique,
    contract_address: deployResponse.contract_address,
    class_hash: classHash,
    constructor_calldata: callData,
    deployer_address: account.address,
    transaction_hash: deployResponse.transaction_hash,
  };
};

export const loadAccountManifestFromCmdArgs = async () => {
  const optionDefinitions = [
    { name: "profile", type: String, defaultOption: true, defaultValue: "dev" },
    { name: "password", alias: "p", type: String, defaultValue: null },
  ];
  const options = commandLineArgs(optionDefinitions);
  return await loadAccountManifest(options.profile, options.password);
};

export const getReturns = async (rpc, txHash) => {
  let receipt;
  try {
    receipt = await rpc.getTransactionReceipt(txHash);
  } catch (e) {
    await rpc.waitForTransaction(txHash);
    receipt = await rpc.getTransactionReceipt(txHash);
  }

  let events = [];

  for (const event of receipt.events) {
    if (event.keys.length && event.keys[0] === returnKey) {
      events.push(event);
    }
  }
  return events;
};
export const getReturn = async (rpc, txHash) => {
  return (await getReturns(rpc, txHash))[0].data;
};
export const dataToUint256 = (data) => {
  return cairo.uint256(data[1] + data[0].substring(2));
};

export const newKeyPair = () => {
  const privateKey = stark.randomAddress();
  const publicKey = ec.starkCurve.getStarkKey(privateKey);
  return {
    privateKey,
    publicKey,
  };
};

export const newAccount = async (account, classHash, erc20) => {
  const { privateKey, publicKey } = newKeyPair();
  const constructorCalldata = CallData.compile({ public_key: publicKey });
  // const contractAddress = hash.calculateContractAddressFromHash(
  //   publicKey,
  //   classHash,
  //   constructorCalldata,
  //   0
  // );
  const { transaction_hash, contract_address } = await account.deployContract(
    {
      classHash,
      salt: publicKey,
      unique: false,
      constructorCalldata,
    },
    { version: 3 }
  );
  // const newAccount = new Account(
  //   { nodeUrl: account.channel.nodeUrl },
  //   contractAddress,
  //   privateKey
  // );
  // await account.execute(
  //   erc20.populate("transfer", {
  //     recipient: contractAddress,
  //     amount: cairo.uint256(30000000000 * 6627),
  //   }),
  //   { version: 3 }
  // );
  // const { transaction_hash, contract_address } = await newAccount.deployAccount(
  //   {
  //     classHash,
  //     constructorCalldata,
  //     addressSalt: publicKey,
  //   },
  //   { version: 3 }
  // );
  // await account.waitForTransaction(transaction_hash, {
  //   retryInterval: 100,
  //   successStates: [
  //     RPC.ETransactionStatus.RECEIVED,
  //     RPC.ETransactionExecutionStatus.SUCCEEDED,
  //     RPC.ETransactionStatus.ACCEPTED_ON_L2,
  //     RPC.ETransactionStatus.ACCEPTED_ON_L1,
  //   ],
  // });

  console.log(`New account deployed with address: ${contract_address}`);
  return new Account(
    { nodeUrl: account.channel.nodeUrl },
    contract_address,
    privateKey
  );
};

export const callOptions = (caller) => {
  const now_seconds = Math.floor(Date.now() / 1000);
  return {
    caller,
    execute_after: now_seconds - 3600,
    execute_before: now_seconds + 3600,
  };
};
