use starknet::{syscalls::deploy_syscall, ContractAddress, testing::set_account_contract_address};
use dojo::{
    test_utils::{deploy_contract, spawn_test_world,}, world::{WorldStorage, ModelStorage,},
};
fn spawn_world() -> WorldStorage {
    let models = array![];
    spawn_test_world(models);
}
