#[starknet::interface]
trait ITest<TContractState> {
    fn test(ref self: TContractState, a: felt252) -> felt252;
}


#[dojo::contract]
mod test_contract {
    use super::ITest;


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        TestEvent: TestEvent,
    }
    #[derive(Drop, starknet::Event)]
    struct TestEvent {
        #[key]
        a: felt252,
    }

    #[abi(embed_v0)]
    impl ITestImpl of ITest<ContractState> {
        fn test(ref self: ContractState, a: felt252) -> felt252 {
            self.emit(Event::TestEvent(TestEvent { a }));
            a + 1
        }
    }
}
