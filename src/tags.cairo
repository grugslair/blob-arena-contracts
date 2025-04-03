use core::{poseidon::poseidon_hash_span, num::traits::One};
use dojo::{world::WorldStorage, model::{ModelStorage, Model}};
use blob_arena::{iter::Iteration, core::byte_array_to_felt252_array};
#[derive(Drop, Serde, PartialEq)]
enum IdTagNew<T> {
    Id: felt252,
    Tag: ByteArray,
    New: T,
}

mod model {
    #[dojo::model]
    #[derive(Drop, Serde)]
    struct Tag {
        #[key]
        group: felt252,
        #[key]
        tag: felt252,
        id: felt252,
    }
}
use model::Tag as TagModel;

#[generate_trait]
impl TagImpl of Tag {
    fn set_tag(ref self: WorldStorage, group: felt252, tag: @ByteArray, id: felt252) {
        self.write_model(@TagModel { group, tag: byte_array_to_tag(tag), id });
    }

    fn set_tags(ref self: WorldStorage, group: felt252, tags: Array<(@ByteArray, felt252)>) {
        let mut models = ArrayTrait::<@TagModel>::new();
        for (tag, id) in tags {
            models.append(@TagModel { group, tag: byte_array_to_tag(tag), id });
        };
        self.write_models(models.span());
    }

    fn get_tag(self: @WorldStorage, group: felt252, tag: @ByteArray) -> felt252 {
        self
            .read_member(
                Model::<TagModel>::ptr_from_keys((group, byte_array_to_tag(tag))), selector!("id"),
            )
    }
}

fn byte_array_to_tag(array: @ByteArray) -> felt252 {
    let len = array.data.len();
    let pending_word = *array.pending_word;
    if len.is_zero() {
        pending_word
    } else if len.is_one() && pending_word.is_zero() {
        (*array.data.at(0)).into()
    } else {
        poseidon_hash_span(byte_array_to_felt252_array(array).span())
    }
}
