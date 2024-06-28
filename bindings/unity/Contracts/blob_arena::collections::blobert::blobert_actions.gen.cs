// Generated by dojo-bindgen on Fri, 28 Jun 2024 10:26:12 +0000. Do not modify this file manually.
using System;
using System.Threading.Tasks;
using Dojo;
using Dojo.Starknet;
using UnityEngine;
using dojo_bindings;
using System.Collections.Generic;
using System.Linq;
using Enum = Dojo.Starknet.Enum;

// System definitions for `blob_arena::collections::blobert::blobert_actions` contract
public class Blobert_actions : MonoBehaviour {
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
            

    
    // Call the `set_seed_item_id` system with the specified Account and calldata
    // Returns the transaction hash. Use `WaitForTransaction` to wait for the transaction to be confirmed.
    public async Task<FieldElement> set_seed_item_id(Account account, BlobertTrait blobert_trait, byte trait_id, BigInteger item_id) {
        List<dojo.FieldElement> calldata = new List<dojo.FieldElement>();
        calldata.Add(new FieldElement(Enum.GetIndex(blobert_trait)).Inner);
		calldata.Add(new FieldElement(trait_id).Inner);
		calldata.Add(new FieldElement(item_id).Inner);

        return await account.ExecuteRaw(new dojo.Call[] {
            new dojo.Call{
                to = contractAddress,
                selector = "set_seed_item_id",
                calldata = calldata.ToArray()
            }
        });
    }
            

    
    // Call the `set_custom_item_id` system with the specified Account and calldata
    // Returns the transaction hash. Use `WaitForTransaction` to wait for the transaction to be confirmed.
    public async Task<FieldElement> set_custom_item_id(Account account, BlobertTrait blobert_trait, byte trait_id, BigInteger item_id) {
        List<dojo.FieldElement> calldata = new List<dojo.FieldElement>();
        calldata.Add(new FieldElement(Enum.GetIndex(blobert_trait)).Inner);
		calldata.Add(new FieldElement(trait_id).Inner);
		calldata.Add(new FieldElement(item_id).Inner);

        return await account.ExecuteRaw(new dojo.Call[] {
            new dojo.Call{
                to = contractAddress,
                selector = "set_custom_item_id",
                calldata = calldata.ToArray()
            }
        });
    }
            
}
        