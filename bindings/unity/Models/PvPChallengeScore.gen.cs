// Generated by dojo-bindgen on Mon, 1 Jul 2024 11:14:10 +0000. Do not modify this file manually.
using System;
using Dojo;
using Dojo.Starknet;
using System.Reflection;
using System.Linq;
using System.Collections.Generic;
using Enum = Dojo.Starknet.Enum;


// Model definition for `blob_arena::models::pvp::PvPChallengeScore` model
public class PvPChallengeScore : ModelInstance {
    [ModelField("player")]
    public FieldElement player;

    [ModelField("collection_address")]
    public FieldElement collection_address;

    [ModelField("token_high")]
    public BigInteger token_high;

    [ModelField("token_low")]
    public BigInteger token_low;

    [ModelField("wins")]
    public ulong wins;

    [ModelField("losses")]
    public ulong losses;

    [ModelField("max_consecutive_wins")]
    public ulong max_consecutive_wins;

    [ModelField("current_consecutive_wins")]
    public ulong current_consecutive_wins;

    // Start is called before the first frame update
    void Start() {
    }

    // Update is called once per frame
    void Update() {
    }
}
        