use core::{poseidon::{HashState}, hash::{Hash}};
use dojo::{world::WorldStorage, model::{ModelValueStorage, ModelStorage, ModelPtr}};

use blob_arena::hash::hash_value;

mod model {
    #[dojo::model]
    #[derive(Drop, Serde)]
    struct Commitment {
        #[key]
        id: felt252,
        commitment: felt252,
    }
}

use model::{CommitmentValue, Commitment as CommitmentModel};


#[generate_trait]
impl CommitmentImpl of Commitment {
    fn get_commitment(self: @WorldStorage, id: felt252) -> felt252 {
        ModelValueStorage::<WorldStorage, CommitmentValue>::read_value(self, id).commitment
    }
    fn set_commitment(ref self: WorldStorage, id: felt252, commitment: felt252) {
        self.write_model(@CommitmentModel { id, commitment });
    }
    fn clear_commitment(ref self: WorldStorage, id: felt252) {
        self.erase_model_ptr(ModelPtr::<CommitmentModel>::Keys([id].span()));
    }
    fn check_commitment_set(self: @WorldStorage, id: felt252) -> bool {
        self.get_commitment(id).is_non_zero()
    }
    fn check_commitment_unset(self: @WorldStorage, id: felt252) -> bool {
        self.get_commitment(id).is_zero()
    }
    fn check_commitments_set(self: @WorldStorage, ids: Span<felt252>) -> bool {
        let (mut n, len) = (0, ids.len());
        let mut set = true;
        while n < len {
            if self.check_commitment_unset(*ids.at(n)) {
                set = false;
                break;
            }
            n += 1;
        };
        set
    }
    fn check_commitments_set_with<T, +Hash<T, HashState>, +Drop<T>, +Copy<T>>(
        self: @WorldStorage, values: Span<T>
    ) -> bool {
        let (mut n, len) = (0, values.len());
        let mut set = true;
        while n < len {
            if self.check_commitment_unset_with(*(values.at(n))) {
                set = false;
                break;
            }
            n += 1;
        };
        set
    }
    fn clear_commitments(ref self: WorldStorage, ids: Span<felt252>) {
        let (mut n, len) = (0, ids.len());
        while n < len {
            self.clear_commitment(*ids.at(n));
            n += 1;
        };
    }
    fn clear_commitments_with<T, +Hash<T, HashState>, +Drop<T>, +Copy<T>>(
        ref self: WorldStorage, values: Span<T>
    ) {
        let (mut n, len) = (0, values.len());
        while n < len {
            self.clear_commitment_with(*(values.at(n)));
            n += 1;
        };
    }

    fn set_new_commitment(ref self: WorldStorage, id: felt252, hash: felt252) {
        assert(!self.check_commitment_set(id), 'Commitment already set');
        self.set_commitment(id, hash);
    }

    fn get_commitment_with<T, +Hash<T, HashState>, +Drop<T>>(
        self: @WorldStorage, value: T
    ) -> felt252 {
        self.get_commitment(hash_value(value))
    }
    fn set_commitment_with<T, +Hash<T, HashState>, +Drop<T>>(
        ref self: WorldStorage, value: T, commitment: felt252
    ) {
        self.set_commitment(hash_value(value), commitment)
    }
    fn clear_commitment_with<T, +Hash<T, HashState>, +Drop<T>>(ref self: WorldStorage, value: T) {
        self.clear_commitment(hash_value(value));
    }
    fn check_commitment_set_with<T, +Hash<T, HashState>, +Drop<T>>(
        self: @WorldStorage, value: T
    ) -> bool {
        self.check_commitment_set(hash_value(value))
    }
    fn check_commitment_unset_with<T, +Hash<T, HashState>, +Drop<T>>(
        self: @WorldStorage, value: T
    ) -> bool {
        !self.check_commitment_set_with(value)
    }
    fn set_new_commitment_with<T, +Hash<T, HashState>, +Drop<T>>(
        ref self: WorldStorage, value: T, hash: felt252
    ) {
        self.set_new_commitment(hash_value(value), hash);
    }
}

