use core::{poseidon::{HashState}, hash::{Hash}};
use dojo::{world::WorldStorage, model::{ModelValueStorage, ModelStorage, Model, ModelPtr}};

use blob_arena::hash::{hash_value, value_to_id};

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
        self.read_member(Model::<CommitmentModel>::ptr_from_keys(id), selector!("commitment"))
    }
    fn set_commitment(ref self: WorldStorage, id: felt252, commitment: felt252) {
        self.write_model(@CommitmentModel { id, commitment });
    }
    fn clear_commitment(ref self: WorldStorage, id: felt252) {
        self.write_member(Model::<CommitmentModel>::ptr_from_keys(id), selector!("commitment"), 0);
    }
    fn clear_commitments(ref self: WorldStorage, ids: Span<felt252>) {
        let mut ptrs = ArrayTrait::<ModelPtr<CommitmentModel>>::new();
        let mut zeros = ArrayTrait::<felt252>::new();
        for id in ids {
            ptrs.append(Model::<CommitmentModel>::ptr_from_keys(*id));
            zeros.append(0);
        };
        self.write_member_of_models(ptrs.span(), selector!("commitment"), zeros.span());
    }
    fn check_commitment_set(self: @WorldStorage, id: felt252) -> bool {
        self.get_commitment(id).is_non_zero()
    }
    fn check_commitment_unset(self: @WorldStorage, id: felt252) -> bool {
        self.get_commitment(id).is_zero()
    }
    fn check_commitments_set(self: @WorldStorage, ids: Span<felt252>) -> bool {
        let mut values: Array<CommitmentValue> = self.read_values(ids);
        loop {
            match values.pop_front() {
                Option::Some(value) => { if value.commitment.is_zero() {
                    break false;
                } },
                Option::None => { break true; },
            }
        }
    }
    fn check_commitments_unset(self: @WorldStorage, ids: Span<felt252>) -> bool {
        let mut values: Array<CommitmentValue> = self.read_values(ids);
        loop {
            match values.pop_front() {
                Option::Some(value) => { if value.commitment.is_non_zero() {
                    break false;
                } },
                Option::None => { break true; },
            }
        }
    }
    fn check_commitments_set_with<T, +Serde<T>, +Drop<T>>(
        self: @WorldStorage, mut values: Span<T>,
    ) -> bool {
        let mut ids: Array<felt252> = ArrayTrait::<felt252>::new();
        for value in values {
            ids.append(value_to_id(value));
        };
        self.check_commitments_set(ids.span())
    }
    fn check_commitments_unset_with<T, +Serde<T>, +Drop<T>>(
        self: @WorldStorage, mut values: Span<T>,
    ) -> bool {
        let mut ids: Array<felt252> = ArrayTrait::<felt252>::new();
        for value in values {
            ids.append(value_to_id(value));
        };
        self.check_commitments_unset(ids.span())
    }
    fn clear_commitments_with<T, +Serde<T>, +Drop<T>, +Copy<T>>(
        ref self: WorldStorage, values: Span<T>,
    ) {
        let mut ptrs = ArrayTrait::<ModelPtr<CommitmentModel>>::new();
        let mut zeros = ArrayTrait::<felt252>::new();
        for value in values {
            ptrs.append(Model::<CommitmentModel>::ptr_from_keys(value_to_id(value)));
            zeros.append(0);
        };
        self.write_member_of_models(ptrs.span(), selector!("commitment"), zeros.span());
    }
    fn check_commitments_are(self: @WorldStorage, ids: Span<felt252>, set: bool) -> Array<bool> {
        let commitments: Array<CommitmentValue> = self.read_values(ids);
        let mut values = ArrayTrait::<bool>::new();
        for commitment in commitments {
            values.append(commitment.commitment.is_non_zero() == set);
        };
        values
    }

    fn set_new_commitment(ref self: WorldStorage, id: felt252, hash: felt252) {
        assert(!self.check_commitment_set(id), 'Commitment already set');
        self.set_commitment(id, hash);
    }

    fn get_commitment_with<T, +Serde<T>>(self: @WorldStorage, value: @T) -> felt252 {
        self.get_commitment(value_to_id(value))
    }
    fn set_commitment_with<T, +Serde<T>>(ref self: WorldStorage, value: @T, commitment: felt252) {
        self.set_commitment(value_to_id(value), commitment)
    }
    fn clear_commitment_with<T, +Serde<T>, +Drop<T>>(ref self: WorldStorage, value: @T) {
        self.clear_commitment(value_to_id(value));
    }
    fn check_commitment_set_with<T, +Serde<T>>(self: @WorldStorage, value: @T) -> bool {
        self.check_commitment_set(value_to_id(value))
    }
    fn check_commitment_unset_with<T, +Serde<T>, +Drop<T>>(self: @WorldStorage, value: @T) -> bool {
        !self.check_commitment_set_with(value)
    }
    fn set_new_commitment_with<T, +Serde<T>>(ref self: WorldStorage, value: @T, hash: felt252) {
        self.set_new_commitment(value_to_id(value), hash);
    }
    fn get_set_commitment(self: @WorldStorage, id: felt252) -> felt252 {
        let commitment = self.get_commitment(id);
        assert(commitment.is_non_zero(), 'Commitment not set');
        commitment
    }
    fn consume_commitment(ref self: WorldStorage, id: felt252) -> felt252 {
        let commitment = self.get_set_commitment(id);
        self.clear_commitment(id);
        commitment
    }
    fn consume_and_compare_commitment_value<T, +Serde<T>>(
        ref self: WorldStorage, id: felt252, value: @T,
    ) -> bool {
        value_to_id(value) == self.consume_commitment(id)
    }
}

