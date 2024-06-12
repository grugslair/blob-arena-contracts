use core::{
    poseidon::{PoseidonTrait, poseidon_hash_span, HashState},
    hash::{HashStateTrait, HashStateExTrait, Hash}
};
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

use blob_arena::models::CommitmentModel;


fn hash_value<T, +Hash<T, HashState>, +Drop<T>>(value: T) -> felt252 {
    PoseidonTrait::new().update_with(value).finalize()
}

#[generate_trait]
impl CommitmentImpl of Commitment {
    fn get_commitment(self: @IWorldDispatcher, id: felt252) -> felt252 {
        get!((*self), id, CommitmentModel).commitment
    }
    fn set_commitment(self: @IWorldDispatcher, id: felt252, commitment: felt252) {
        set!((*self), CommitmentModel { id, commitment });
    }
    fn clear_commitment(self: @IWorldDispatcher, id: felt252) {
        self.set_commitment(id, 0);
    }
    fn check_commitment_set(self: @IWorldDispatcher, id: felt252) -> bool {
        self.get_commitment(id).is_non_zero()
    }
    fn set_new_commitment(self: @IWorldDispatcher, id: felt252, hash: felt252) {
        assert(!self.check_commitment_set(id), 'Commitment already set');
        self.set_commitment(id, hash);
    }

    fn get_commitment_with<T, +Hash<T, HashState>, +Drop<T>>(
        self: @IWorldDispatcher, value: T
    ) -> felt252 {
        self.get_commitment(hash_value(value))
    }
    fn set_commitment_with<T, +Hash<T, HashState>, +Drop<T>>(
        self: @IWorldDispatcher, value: T, commitment: felt252
    ) {
        self.set_commitment(hash_value(value), commitment)
    }
    fn clear_commitment_with<T, +Hash<T, HashState>, +Drop<T>>(self: @IWorldDispatcher, value: T) {
        self.clear_commitment(hash_value(value));
    }
    fn check_commitment_set_with<T, +Hash<T, HashState>, +Drop<T>>(
        self: @IWorldDispatcher, value: T
    ) -> bool {
        self.check_commitment_set(hash_value(value))
    }
    fn set_new_commitment_with<T, +Hash<T, HashState>, +Drop<T>>(
        self: @IWorldDispatcher, value: T, hash: felt252
    ) {
        self.set_new_commitment(hash_value(value), hash);
    }
}

