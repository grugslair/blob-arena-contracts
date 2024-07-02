// Generated by dojo-bindgen on Mon, 1 Jul 2024 21:02:30 +0000. Do not modify this file manually.
using System;
using System.Threading.Tasks;
using Dojo;
using Dojo.Starknet;
using UnityEngine;
using dojo_bindings;
using System.Collections.Generic;
using System.Linq;
using Enum = Dojo.Starknet.Enum;

// System definitions for `blob_arena::contracts::attack::attack_actions` contract
public class Attack_actions : MonoBehaviour {
    // The address of this contract
    public string contractAddress;

    
    // Call the `dojo_init` system with the specified Account and calldata
    // Returns the transaction hash. Use `WaitForTransaction` to wait for the transaction to be confirmed.
    public async Task<FieldElement> dojo_init(Account account) {
        List<dojo.FieldElement> calldata = new List<dojo.FieldElement>();
        

        return await account.ExecuteRaw(new dojo.Call[] {
            new dojo.Call{
                to = contractAddress,
                selector = "dojo_init",
                calldata = calldata.ToArray()
            }
        });
    }
            
}
        