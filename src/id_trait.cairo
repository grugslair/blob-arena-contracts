trait IdTrait<T> {
    fn id(self: @T) -> felt252;
}

trait IdsTrait<T> {
    fn ids(self: Span<T>) -> Span<felt252>;
}

impl TIdsImpl<T, +IdTrait<T>, +Drop<T>> of IdsTrait<T> {
    fn ids(self: Span<T>) -> Span<felt252> {
        let mut ids: Array<felt252> = ArrayTrait::new();
        let (len, mut n) = (self.len(), 0_usize);
        while (n < len) {
            ids.append(self.at(n).id());
            n += 1;
        };
        ids.span()
    }
}
