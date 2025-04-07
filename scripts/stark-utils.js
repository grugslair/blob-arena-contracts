import { Contract, CairoCustomEnum, Account } from "starknet";
import { upperFirst, camelCase } from "lodash-es";
import { fileURLToPath } from "url";
import { dirname } from "path";
import * as fs from "fs";
import * as path from "path";
import * as accounts from "web3-eth-accounts";
import * as toml from "toml";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

export const pascalCase = (str) => {
  return upperFirst(camelCase(str));
};

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
  console.log(contractAddress);
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
  constructor(dojo_toml_path, manifest_path) {
    this.dojo_toml = loadToml(dojo_toml_path);
    this.manifest = loadJson(manifest_path);
    this.contracts = {};
  }

  async init(password) {
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
    const transaction = await this.account.execute(calls);
    return this.account.waitForTransaction(transaction.transaction_hash);
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

export const loadAccountManifest = async (profile, password) => {
  const account_manifest = new AccountManifest(
    `../dojo_${profile}.toml`,
    `../manifest_${profile}.json`
  );
  await account_manifest.init(password);
  return account_manifest;
};
