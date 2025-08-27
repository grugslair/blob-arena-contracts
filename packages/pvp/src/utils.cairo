pub fn pad_to_fixed(arr: Array<felt252>) -> [felt252; 4] {
    let mut arr = arr;
    let len = arr.len();
    assert(len <= 4, 'Array too large to pad');
    for _ in 0..(4 - len) {
        arr.append(0);
    }
    let box = TryInto::try_into(arr.span()).unwrap();
    (*box).unbox()
}
