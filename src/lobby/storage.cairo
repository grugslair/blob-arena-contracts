use starknet::ContractAddress;
use dojo::{
    world::WorldStorage, model::{ModelStorage, Model, ModelValueStorage}, event::EventStorage,
};
use blob_arena::lobby::components::{Lobby, LobbyCreated};


#[generate_trait]
impl LobbyStorageImpl of LobbyStorage {
    fn create_lobby(ref self: WorldStorage, id: felt252, receiver: ContractAddress) {
        // self.write_model(@Lobby { id, open: true, responded: false });
        self.write_model(@Lobby { id, receiver, open: true });
    }
    fn get_lobby(self: @WorldStorage, id: felt252) -> Lobby {
        self.read_model(id)
    }
    fn get_lobby_open(self: @WorldStorage, id: felt252) -> bool {
        self.read_member(Model::<Lobby>::ptr_from_keys(id), selector!("open"))
    }
    fn close_lobby(ref self: WorldStorage, id: felt252) {
        self.write_member(Model::<Lobby>::ptr_from_keys(id), selector!("open"), false);
    }
    fn emit_lobby_created(
        ref self: WorldStorage, id: felt252, sender: ContractAddress, receiver: ContractAddress,
    ) {
        self.emit_event(@LobbyCreated { id, sender, receiver });
    }
    // fn set_lobby_response(ref self: WorldStorage, id: felt252, response: bool) {
//     self.write_member(Model::<Lobby>::ptr_from_keys(id), selector!("responded"), response);
// }
}
