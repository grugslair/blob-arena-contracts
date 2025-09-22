import {
  Contract,
  CairoCustomEnum,
  Account,
  hash,
  stark,
  CallData,
  config,
  RPC,
  legacyDeployer,
} from "starknet";
import {
  loadJson,
  loadToml,
  resolvePath,
  declareContract,
  deployContract,
  calculateUDCContractAddressFromHash,
  dumpJson,
  getReturns,
  isContractDeployed,
  compileConstructor,
  checkClassDeclared,
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

const successStates = ["RECEIVED", "ACCEPTED_ON_L2", "ACCEPTED_ON_L1"];

const valueIsSet = (val) =>
  val !== null && val !== undefined && val !== false && val !== "";
const valueIfSet = (val, defaultValue) =>
  valueIsSet(val) ? val : defaultValue;
const boolIsSet = (val) => val !== null && val !== undefined;
const boolIfSet = (val, defaultValue) => (boolIsSet(val) ? val : defaultValue);
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
  return new Account({
    provider: { nodeUrl },
    address: accountAddress,
    signer: privateKey,
    deployer: legacyDeployer,
  });
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
    optionalConfig
  ) {
    const { transactionDetails } = optionalConfig || {};

    this.profile_config = profile_config;
    this.name = name;
    this.profile = profile;
    this.declarations = {};
    this.deployments = {};
    this.declare = profile_config.declare || {};
    this.deploy = profile_config.deploy || {};
    this.classes = profile_config.classes || {};
    this.abis = {};
    this.contracts = profile_config.contracts || {};
    this.account = account;
    this.directoryPath = directoryPath || process.cwd();
    this.targetPath = targetPath || `${directoryPath}/target/${profile}`;
    this.transactionDetails = transactionDetails;
    this.variables = profile_config.variables || {};
    this.defaultSalt = valueIsSet(profile_config.defaults.salt)
      ? profile_config.defaults.salt
      : stark.randomAddress();
    this.defaultUnique = boolIfSet(profile_config.defaults.unique, false);
    this.defaultOnce = boolIfSet(profile_config.defaults.once, true);
  }
  addClass(tag, class_hash, abi) {
    this.classes[tag] = { class_hash };
    if (abi == true) {
      this.classes[tag].abi = abi;
      this.abis[class_hash] = abi;
    }
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
    const { deployments, classes, contracts, declarations, abis } = this;
    dumpJson({ deployments, classes, contracts, declarations, abis }, dumpPath);
  }

  getClassData(tag, { name, contract_path, casm_path } = {}) {
    const fileName = `${this.targetPath}/${this.name}_${name || tag}`;
    const contractPath = contract_path || `${fileName}.contract_class.json`;
    casm_path = casm_path || `${fileName}.compiled_contract_class.json`;
    const contract = loadJson(contractPath);
    const class_hash = hash.computeContractClassHash(contract);
    return { tag, name, contract, casm_path, class_hash };
  }

  async checkClassDeployed(data) {
    const class_hash =
      typeof data === "string" ? data : data.class_hash || data.classHash;
    return await checkClassDeclared(this.account, class_hash);
  }

  async declareClass(tag, classData = {}) {
    const { class_hash, contract, casm_path } = this.getClassData(
      tag,
      classData
    );
    if (await this.checkClassDeployed(classData)) {
      console.log(`${tag} already declared`);
    } else {
      console.log(`Declaring ${tag}...`);
      const { transaction_hash } = await this.account.declare({
        casm: loadJson(casm_path),
        contract,
      });
      await this.account.waitForTransaction(transaction_hash, {
        successStates,
      });
      this.declarations[tag] = { class_hash, transaction_hash };
    }
    this.addClass(tag, class_hash, contract.abi);
  }

  async declareAllClasses() {
    const classDatas = Object.entries(this.declare).map(([tag, data]) =>
      this.getClassData(tag, data)
    );
    const isDeployed = await Promise.all(
      classDatas.map((data) => this.checkClassDeployed(data))
    );
    for (let i = 0; i < classDatas.length; i++) {
      const { contract, class_hash, tag, casm_path } = classDatas[i];
      if (isDeployed[i]) {
        console.log(` - ${classDatas[i].tag} already declared`);
      } else {
        console.log(` - Declaring ${classDatas[i].tag}...`);
        const casm = loadJson(casm_path);
        const { transaction_hash } = await this.account.declare({
          casm,
          contract,
        });
        await this.account.waitForTransaction(transaction_hash, {
          successStates,
        });
        this.declarations[tag] = { class_hash, transaction_hash };
      }
      this.addClass(tag, class_hash, contract.abi);
    }
  }

  async compileCalldataFromClassHash(classHash, method, calldata) {
    const abi = await this.getAbiFromClassHash(classHash);
    if (method === "constructor") {
      return compileConstructor(abi, calldata);
    }
    return CallData.toHex(new CallData(abi).compile(method, calldata));
  }
  async parseDeployData(data) {
    data.salt = valueIfSet(data.salt, this.defaultSalt);
    data.unique = boolIfSet(data.unique, this.defaultUnique);
    data.once = boolIfSet(data.once, this.defaultOnce);
    if (!data.class_hash) {
      data.class = data.class || data.tag;
      data.class_hash = this.classes[data.class].class_hash;
    }
    data.calldata = data.calldata || [];
    data.calldata_compiled = Array.isArray(data.calldata)
      ? data.calldata
      : await this.compileCalldataFromClassHash(
          data.class_hash,
          "constructor",
          data.calldata
        );

    return data;
  }
  addDeployment(tag, contract_address, deployment) {
    this.contracts[tag] = {
      contract_address,
      class_hash: deployment.class_hash,
    };
    if (deployment.class) {
      this.contracts[tag].class = deployment.class;
    }
    this.deployments[tag] = {
      contract_address,
      ...deployment,
      ...this.deployments[tag],
    };
  }
  async deployContract(contracts, transactionDetails) {
    const contractList = Array.isArray(contracts) ? contracts : [contracts];
    const toDeploy = [];

    console.log("Deploying ");
    for (const data of contractList) {
      await this.parseDeployData(data);
      if (data.once) {
        const contract_address = calculateUDCContractAddressFromHash(
          this.account.address,
          data.class_hash,
          data.salt,
          data.unique,
          data.calldata_compiled
        );
        if (await isContractDeployed(this.account, contract_address)) {
          const tag = data.tag || contract_address;
          this.addDeployment(tag, contract_address, data);
          console.log(` - ${tag} already deployed`);
          continue;
        }
      }
      console.log(` - ${data.tag || data.class || data.class_hash}...`);
      toDeploy.push(data);
    }
    if (toDeploy.length) {
      const payload = toDeploy.map(deploymentToPayload);
      const { contract_address: ContractAddresses, transaction_hash } =
        await this.account.deploy(payload, {
          ...this.transactionDetails,
          ...transactionDetails,
        });
      toDeploy.map((data, index) => {
        const contract_address = ContractAddresses[index];
        const tag = data.tag || contract_address;
        this.addDeployment(tag, contract_address, data);
      });
      await this.account.waitForTransaction(transaction_hash, {
        successStates,
      });
    }
  }
  async executeAndWait(calls, transactionDetails) {
    const { transaction_hash } = await this.account.execute(calls, {
      ...this.transactionDetails,
      ...transactionDetails,
    });
    await this.account.waitForTransaction(transaction_hash, { successStates });
    return transaction_hash;
  }

  async executeWithReturn(calls, transactionDetails) {
    const { transaction_hash } = await this.account.execute(calls, {
      ...this.transactionDetails,
      ...transactionDetails,
    });

    await this.account.waitForTransaction(transaction_hash, { successStates });
    return getReturns(this.account, transaction_hash);
  }

  async getContract(tag) {
    const contract = this.contracts[tag];
    if (!contract) {
      throw new Error(`Contract with tag ${tag} not found`);
    }
    const abi = await this.getAbiFromContract(tag);
    return new Contract({
      abi,
      address: contract.contract_address,
      providerOrAccount: this.account,
    });
  }

  async getAbiFromContract(tag) {
    const contract = this.contracts[tag];
    if (!contract) {
      throw new Error(`Contract with tag ${tag} not found`);
    }
    if (!contract.class_hash) {
      await this.getClassHashFromContract(tag);
    }
    return await this.getAbiFromClassHash(contract.class_hash);
  }

  async getClassHashFromContract(tag) {
    const contract = this.contracts[tag];
    if (!contract) {
      throw new Error(`Contract with tag ${tag} not found`);
    }
    if (!contract.class_hash) {
      contract.class_hash = await this.account.getClassHashAt(
        contract.contract_address
      );
    }
    return contract.class_hash;
  }

  async getAbiFromClassHash(classHash) {
    if (!this.abis[classHash]) {
      this.abis[classHash] = (await this.account.getClassByHash(classHash)).abi;
    }
    return this.abis[classHash];
  }

  async getAbiFromClass(tag) {
    const classs = this.classes[tag];
    if (!classs) {
      throw new Error(`Class with tag ${tag} not found`);
    }
    return await this.getAbiFromClassHash(classs.class_hash);
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
            const call = contract.populate("grant_contract_owner", {
              owner: owners,
            });
            return call;
          }
        }
      )
    );
  }
}

const deploymentToPayload = (deployment) => {
  return {
    classHash: deployment.class_hash,
    salt: deployment.salt,
    unique: deployment.unique,
    constructorCalldata: deployment.calldata_compiled,
  };
};

export const loadSai = async (saiConfig) => {
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
    profile_toml,
    saiConfig
  );
};
