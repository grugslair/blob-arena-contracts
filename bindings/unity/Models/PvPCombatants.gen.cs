// Generated by dojo-bindgen on Mon, 1 Jul 2024 21:02:30 +0000. Do not modify this file manually.
using System;
using Dojo;
using Dojo.Starknet;
using System.Reflection;
using System.Linq;
using System.Collections.Generic;
using Enum = Dojo.Starknet.Enum;


// Model definition for `blob_arena::models::pvp::PvPCombatants` model
public class PvPCombatants : ModelInstance {
    [ModelField("id")]
    public BigInteger id;

    [ModelField("combatants")]
    public (BigInteger, BigInteger) combatants;

    // Start is called before the first frame update
    void Start() {
    }

    // Update is called once per frame
    void Update() {
    }
}
        