import { Contract, CairoCustomEnum, Account, hash, stark } from "starknet";
import {
  loadJson,
  loadToml,
  resolvePath,
  declareContract,
  deployContract,
  calculateUDCContractAddressFromHash,
  dumpJson,
  getReturns,
} from "./stark-utils.js";
import commandLineArgs from "command-line-args";
import * as accounts from "web3-eth-accounts";

export const cmdOptions = [
  { name: "profile", type: String, defaultOption: true, defaultValue: "dev" },
  { name: "password", alias: "p", type: String, defaultValue: null },
  { name: "keystore_path", alias: "k", type: String, defaultValue: null },
  { name: "account_address", alias: "A", type: String, defaultValue: null },
  { name: "rpc_url", alias: "u", type: String, defaultValue: null },
  { name: "directory_path", alias: "d", type: String, defaultValue: "." },
];

export const readKeystorePK = async (
  keystorePath,
  accountAddress,
  password
) => {
  let data = loadJson(keystorePath);
  data.address = accountAddress;
  return (await accounts.decrypt(data, password)).privateKey;
};

const loadAccount = async (account, cmdOptions) => {
  const accountAddress = cmdOptions.account_address || account.account_address;
  const nodeUrl = cmdOptions.rpc_url || account.rpc_url;
  let privateKey = cmdOptions.private_key || account.private_key;
  if (privateKey == null) {
    const keystorePath = cmdOptions.keystore_path || account.keystore_path;
    const password = cmdOptions.password || account.password;
    privateKey = await readKeystorePK(keystorePath, accountAddress, password);
  }
  return new Account({ nodeUrl }, accountAddress, privateKey);
};

const declareContracts = async (
  account,
  targetPath,
  projectName,
  contracts
) => {
  let declarations = {};
  for (const { tag, contract_name } of contracts) {
    const name = contract_name || tag;
    const contractPath = `${targetPath}/${projectName}_${name}.contract_class.json`;
    const casmPath = `${targetPath}/${projectName}_${name}.compiled_contract_class.json`;
    declarations[tag] = await declareContract(account, contractPath, casmPath);
  }
  return declarations;
};

const parseDeployContractData = (data) => {};

const deployContracts = async (account, declarations, contracts) => {
  let deployed = {};
  for (const { tag, contract_tag, salt, unique, calldata } of contracts) {
    const { classHash, abi } = declarations[contract_tag];

    const contractAddress = calculateUDCContractAddressFromHash(
      account.address,
      classHash,
      salt,
      unique,
      calldata
    );

    try {
      deployed[tag] = {
        tag,
        contract_tag,
        ...(await deployContract(account, classHash, calldata, salt, unique)),
      };
    } catch (e) {
      console.error(e);
      deployed[tag] = {
        tag,
        contract_tag,
        salt,
        unique,
        calldata,
        contract_address: calculateUDCContractAddressFromHash(
          account.address,
          classHash,
          salt,
          unique,
          calldata
        ),
      };
    }
  }
  return deployed;
};

export class SaiConfig {
  constructor(profile, contracts, name, account) {
    this.contracts = contracts;
    this.profile = profile;
    this.name = name;
  }
}

export class SaiProject {
  constructor(
    profile,
    account,
    name,
    directoryPath,
    targetPath,
    profile_config,
    transactionDetails
  ) {
    this.profile_config = profile_config;
    this.name = name;
    this.profile = profile;
    this.declarations = {};
    this.deployments = {};
    this.declare = profile_config.declare || {};
    this.deploy = profile_config.deploy || {};
    this.classes = profile_config.classes || {};
    this.contracts = profile_config.contracts || {};
    this.account = account;
    this.directoryPath = directoryPath || process.cwd();
    this.targetPath = targetPath || `${directoryPath}/target/${profile}`;
    this.transactionDetails = transactionDetails;
    this.variables = profile_config.variables || {};
  }

  loadManifest(path) {
    const manifestPath =
      path || `${this.directoryPath}/manifest_${this.profile}.json`;
    console.log(`Reading SAI profile: ${this.profile} from ${manifestPath}`);
    const manifest = loadJson(manifestPath);
    this.deployments = { ...this.deployments, ...(manifest.deployments || {}) };
    this.classes = { ...this.classes, ...(manifest.classes || {}) };
    this.contracts = { ...this.contracts, ...(manifest.contracts || {}) };
    this.declarations = {
      ...this.declarations,
      ...(manifest.declarations || {}),
    };
    return this;
  }

  dumpManifest(path) {
    const dumpPath =
      path || `${this.directoryPath}/manifest_${this.profile}.json`;
    console.log(`Dumping SAI profile: ${this.profile} to ${dumpPath}`);
    dumpJson(
      {
        deployments: this.deployments,
        classes: this.classes,
        contracts: this.contracts,
        declarations: this.declarations,
      },
      dumpPath
    );
  }

  async declareClass(tag, { name, contract_path, casm_path } = {}) {
    const contractPath =
      contract_path ||
      `${this.targetPath}/${this.name}_${name || tag}.contract_class.json`;
    const casmPath =
      casm_path ||
      `${this.targetPath}/${this.name}_${
        name || tag
      }.compiled_contract_class.json`;
    console.log(`Declaring class ${tag}`);
    this.declarations[tag] = await declareContract(
      this.account,
      contractPath,
      casmPath
    );
    this.classes[tag] = {
      class_hash: this.declarations[tag].class_hash,
      abi: this.declarations[tag].abi,
    };
  }

  async declareAllClasses() {
    for (const [tag, { name, contract_path, casm_path }] of Object.entries(
      this.declare
    )) {
      await this.declareClass(tag, { name, contract_path, casm_path });
    }
  }

  async deployContract(contracts, transactionDetails) {
    const contractList = Array.isArray(contracts) ? contracts : [contracts];
    const payload = [];
    console.log("Deploying ");
    for (const data of contractList) {
      console.log(` - ${data.tag || data.class}...`);
      data.salt = data.salt || stark.randomAddress();
      const classData = (data.class && this.classes[data.class]) || {};
      data.class_hash = data.class_hash || classData.class_hash;
      payload.push({
        classHash: data.class_hash,
        salt: data.salt,
        unique: data.unique,
        constructorCalldata: data.calldata,
      });
    }

    const { contract_address: ContractAddresses, transaction_hash } =
      await this.account.deploy(payload, {
        ...this.transactionDetails,
        ...transactionDetails,
      });
    await this.account.waitForTransaction(transaction_hash);

    contractList.map((data, index) => {
      const contract_address = ContractAddresses[index];
      const tag = data.tag || contract_address;
      this.deployments[tag] = {
        ...data,
        contract_address,
        deployer_address: this.account.address,
        transaction_hash,
      };
      this.contracts[tag] = {
        contract_address,
        class_hash: data.class_hash,
        class: data.class,
      };
    });
  }
  async executeAndWait(calls, transactionDetails) {
    const { transaction_hash } = await this.account.execute(calls, {
      ...this.transactionDetails,
      ...transactionDetails,
    });
    await this.account.waitForTransaction(transaction_hash);
    return transaction_hash;
  }

  async executeWithReturn(calls, transactionDetails) {
    const { transaction_hash } = await this.account.execute(calls, {
      ...this.transactionDetails,
      ...transactionDetails,
    });

    await this.account.waitForTransaction(transaction_hash);
    return getReturns(this.account, transaction_hash);
  }

  async getContract(tag) {
    if (!this.contracts[tag]) {
      throw new Error(`Contract with tag ${tag} not found`);
    }
    const contract = this.contracts[tag];
    if (!contract.abi) {
      const { abi } = await this.account.getClassAt(contract.contract_address);
      contract.abi = abi;
    }
    return new Contract(contract.abi, contract.contract_address, this.account);
  }

  async deployAllContracts() {
    const contractList = Object.entries(this.deploy).map(([tag, data]) => ({
      tag,
      ...data,
    }));
    await this.deployContract(contractList);
  }

  async grantWritersCalls() {
    return await Promise.all(
      Object.entries(this.profile_config.writers).map(
        async ([tag, writers]) => {
          const contract = await this.getContract(tag);
          if (Array.isArray(writers)) {
            return contract.populate("grant_contract_writers", {
              writers,
            });
          } else {
            return contract.populate("grant_contract_writer", {
              writer: writers,
            });
          }
        }
      )
    );
  }

  async grantOwnersCalls() {
    return await Promise.all(
      Object.entries(this.profile_config.owners || {}).map(
        async ([tag, owners]) => {
          const contract = await this.getContract(tag);
          if (Array.isArray(owners)) {
            return contract.populate("grant_contract_owners", {
              owners,
            });
          } else {
            return contract.populate("grant_contract_owner", {
              owner: owners,
            });
          }
        }
      )
    );
  }
}

export const loadSai = async () => {
  const cmdArgs = commandLineArgs(cmdOptions);

  const directoryPath = resolvePath(cmdArgs.directory_path);
  const scarb_toml = loadToml(`${directoryPath}/Scarb.toml`);
  const profile_toml = loadToml(`${directoryPath}/sai_${cmdArgs.profile}.toml`);
  const account = await loadAccount(profile_toml.account, cmdArgs);
  console.log(`Loading SAI profile: ${cmdArgs.profile} from ${directoryPath}`);

  return new SaiProject(
    cmdArgs.profile,
    account,
    scarb_toml.package.name,
    directoryPath,
    null,
    profile_toml
  );
};
