use core::poseidon::poseidon_hash_span;
use crate::storage::{read_value_from_felt252, write_value_from_felt252};

const PLAYER_TOKEN_SELECTOR: felt252 = selector!('player-token-experience');
const PLAYER_COLLECTION_SELECTOR: felt252 = selector!('player-collection-experience');
const PLAYER_SELECTOR: felt252 = selector!('player-experience');
const TOKEN_SELECTOR: felt252 = selector!('token-experience');
const COLLECTION_SELECTOR: felt252 = selector!('collection-experience');
const TOTAL_SELECTOR: felt252 = selector!('total-experience');
const EXPERIENCE_CAP_SELECTOR: felt252 = selector!('experience-cap');
const WRITER_SELECTOR: felt252 = selector!('writer');

fn read_player_token(player: ContractAddress, token: felt252) -> u128 {
    read_value_from_felt252(
        poseidon_hash_span([PLAYER_TOKEN_SELECTOR, player.into(), token].span()),
    )
}

fn write_player_token(player: ContractAddress, token: felt252, experience: u128) {
    write_value_from_felt252(
        poseidon_hash_span([PLAYER_TOKEN_SELECTOR, player.into(), token].span()), experience,
    );
}
fn read_player_collection(player: ContractAddress, collection: ContractAddress) -> u128 {
    read_value_from_felt252(
        poseidon_hash_span([PLAYER_COLLECTION_SELECTOR, player.into(), collection.into()].span()),
    )
}
fn write_player_collection(player: ContractAddress, collection: ContractAddress, experience: u128) {
    write_value_from_felt252(
        poseidon_hash_span([PLAYER_COLLECTION_SELECTOR, player.into(), collection.into()].span()),
        experience,
    );
}
fn read_player(player: ContractAddress) -> u128 {
    read_value_from_felt252(poseidon_hash_span([PLAYER_SELECTOR, player.into()].span()))
}
fn write_player(player: ContractAddress, experience: u128) {
    write_value_from_felt252(
        poseidon_hash_span([PLAYER_SELECTOR, player.into()].span()), experience,
    );
}
fn read_token(token: felt252) -> u128 {
    read_value_from_felt252(poseidon_hash_span([TOKEN_SELECTOR, token].span()))
}
fn write_token(token: felt252, experience: u128) {
    write_value_from_felt252(poseidon_hash_span([TOKEN_SELECTOR, token].span()), experience);
}
fn read_collection(collection: ContractAddress) -> u128 {
    read_value_from_felt252(poseidon_hash_span([COLLECTION_SELECTOR, collection.into()].span()))
}
fn write_collection(collection: ContractAddress, experience: u128) {
    write_value_from_felt252(
        poseidon_hash_span([COLLECTION_SELECTOR, collection.into()].span()), experience,
    );
}
fn read_total() -> u128 {
    read_value_from_felt252(TOTAL_SELECTOR)
}
fn write_total(experience: u128) {
    write_value_from_felt252(TOTAL_SELECTOR, experience);
}

fn read_writer(caller: ContractAddress) -> bool {
    read_value_from_felt252(poseidon_hash_span([WRITER_SELECTOR, caller.into()].span()))
}

fn write_writer(caller: ContractAddress, value: bool) {
    write_value_from_felt252(poseidon_hash_span([WRITER_SELECTOR, caller.into()].span()), value);
}
