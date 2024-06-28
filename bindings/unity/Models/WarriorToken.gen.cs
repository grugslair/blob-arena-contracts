// Generated by dojo-bindgen on Wed, 26 Jun 2024 09:53:14 +0000. Do not modify this file manually.
using System;
using Dojo;
using Dojo.Starknet;
using System.Reflection;
using System.Linq;
using System.Collections.Generic;
using Enum = Dojo.Starknet.Enum;

// Type definition for `core::integer::u256` struct
[Serializable]
public struct U256 {
    public BigInteger low;
    public BigInteger high;
}


// Model definition for `blob_arena::models::warrior::WarriorToken` model
public class WarriorToken : ModelInstance {
    [ModelField("id")]
    public BigInteger id;

    [ModelField("collection_address")]
    public FieldElement collection_address;

    [ModelField("token_id")]
    public U256 token_id;

    // Start is called before the first frame update
    void Start() {
    }

    // Update is called once per frame
    void Update() {
    }
}
        