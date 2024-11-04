use starknet::ContractAddress;
use dojo::{world::WorldStorage, model::{ModelStorage, ModelValueStorage}};
use blob_arena::collections::blobert::{external::TokenTrait};

#[dojo::model]
#[derive(Drop, Serde, Copy)]
struct ArcadeBlobert {
    #[key]
    token_id: felt252,
    owner: ContractAddress,
    traits: TokenTrait
}


#[generate_trait]
impl ArcadeBlobertImpl of ArcadeBlobertTrait {
    fn set_arcade_blobert(
        ref self: WorldStorage, token_id: felt252, owner: ContractAddress, traits: TokenTrait
    ) {
        self.write_model(@ArcadeBlobert { token_id, owner, traits });
    }

    fn get_arcade_blobert<T, +TryInto<T, felt252>>(
        self: @WorldStorage, token_id: T
    ) -> ArcadeBlobert {
        let token_id: felt252 = token_id.try_into().unwrap();
        self.read_model(token_id)
    }
    fn get_arcade_blobert_owner<T, +TryInto<T, felt252>>(
        self: @WorldStorage, token_id: u256
    ) -> ContractAddress {
        self.get_arcade_blobert(token_id).owner
    }

    fn get_arcade_blobert_traits<T, +TryInto<T, felt252>>(
        self: @WorldStorage, token_id: u256
    ) -> TokenTrait {
        self.get_arcade_blobert(token_id).traits
    }
}
