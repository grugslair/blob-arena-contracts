#[starknet::interface]
trait IEndless<TState> {
    fn claim_jackpot(ref self: TState, season: u64, place: u8);
    fn start_attempt(ref self: TState) -> u64;
}

#[starknet::component]
mod endless_component {
    use ba_loadout::Attributes;
    use openzeppelin_token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address};
    use crate::season::{JackpotSplits, SeasonNode, SeasonTrait};
    use super::IEndless;

    #[storage]
    struct Storage {
        current_season: u64,
        season_length: u64,
        splits: JackpotSplits,
        seasons: Map<u64, SeasonNode>,
        jackpot: u256,
        jackpot_token: ERC20ABIDispatcher,
    }

    #[embeddable_as(EndlessImpl)]
    impl IEndlessImpl<
        TContractState, +HasComponent<TContractState>,
    > of IEndless<ComponentState<TContractState>> {
        fn claim_jackpot(ref self: ComponentState<TContractState>, season: u64, place: u8) {
            let season_node = self.seasons.entry(season);
            season_node.assert_ended();
            let winners = season_node.winners.read();
            let splits = self.splits.read();
            let (attempt_id, split) = match place {
                0 => panic!("Place needs to be 1, 2, or 3"),
                1 => (winners.first_attempt, splits.first),
                2 => (winners.second_attempt, splits.second),
                3 => (winners.third_attempt, splits.third),
                _ => panic!("Place needs to be 1, 2, or 3"),
            };
            let portion = self.jackpot.read() * split.into() / 1000;
            assert(!season_node.claimed.read(place), 'Already Claimed');
            let attempt_node = season_node.attempts.entry(attempt_id);
            let user = attempt_node.player.read();
            self.jackpot_token.read().transfer(user, portion);
        }


        fn start_attempt(ref self: ComponentState<TContractState>) -> u64 {
            let season_node = self.seasons.entry(self.current_season.read());
            let attempt_id = season_node.n_attempts.read() + 1;
            season_node.n_attempts.write(attempt_id);
            let dispatcher = self.jackpot_token.read();
            let attempt_node = season_node.attempts.entry(attempt_id);
            0
        }
    }


    #[generate_trait]
    impl PrivateImpl<TState> of PrivateTrait<TState> {
        fn start_attempt_private(
            ref self: ComponentState<TState>,
            attempt_id: u64,
            player: ContractAddress,
            attributes: Attributes,
        ) {
            let season_node = self.seasons.entry(self.current_season.read());
            let attempt_node = season_node.attempts.entry(attempt_id);
            assert(attempt_node.player.read() == player, 'Attempt already exists');
        }
    }
}
