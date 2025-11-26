#[starknet::interface]
trait IEndless<TState> {
    fn claim_jackpot(ref self: TState, season: u64, place: u8);
    fn start_attempt(ref self: TState) -> u64;
}

#[starknet::component]
mod endless_component {
    use ba_loadout::Attributes;
    use core::cmp::min;
    use openzeppelin_token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_contract_address};
    use crate::attempt::{AttemptInfo, AttemptInfoTrait, AttemptNodePath};
    use crate::season::{JackpotSplits, SeasonNode, SeasonNodePath, SeasonTrait};
    use super::IEndless;

    #[storage]
    struct Storage {
        current_season: u64,
        season_length: u64,
        splits: JackpotSplits,
        seasons: Map<u64, SeasonNode>,
        jackpot: u256,
        jackpot_token: ERC20ABIDispatcher,
        team_wallet: ContractAddress,
        vlords_wallet: ContractAddress,
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
    }


    #[generate_trait]
    impl PrivateImpl<TState> of PrivateTrait<TState> {
        fn init_attempt(
            ref self: ComponentState<TState>, attempt_id: u64, player: ContractAddress,
        ) {
            let season_node = self.seasons.entry(self.current_season.read());
            self.pay_entry(season_node, player);
            let attempt_node = season_node.attempts.entry(attempt_id);
            attempt_node.player.write(player);
            let times = season_node.times.read();
            let expiry = min(get_block_timestamp() + times.limit, times.end);
            let attempt_info = AttemptInfoTrait::new(expiry);
            attempt_node.info.write(attempt_info);
        }

        fn start_attempt_private(
            ref self: ComponentState<TState>,
            attempt_id: u64,
            player: ContractAddress,
            attributes: Attributes,
        ) {
            let season_node = self.seasons.entry(self.current_season.read());
            let attempt_id = season_node.n_attempts.read() + 1;
            season_node.n_attempts.write(attempt_id);
            let attempt_node = season_node.attempts.entry(attempt_id);
            attempt_node.attributes.write(attributes);
        }

        fn pay_entry(
            ref self: ComponentState<TState>, season_node: SeasonNodePath, player: ContractAddress,
        ) {
            let splits = season_node.jackpot_splits.read();

            let current_jackpot = season_node.jackpot.read();
            let entry_fee = self.get_entry_fee(current_jackpot);
            let team_fee = entry_fee * splits.team.into() / 1_000_000;
            let vlords_fee = entry_fee * splits.vlords.into() / 1_000_000;
            let jackpot_amount = entry_fee - team_fee - vlords_fee;
            let dispatcher = self.jackpot_token.read();
            dispatcher.transfer_from(player, self.team_wallet.read(), team_fee);
            dispatcher.transfer_from(player, self.vlords_wallet.read(), vlords_fee);
            dispatcher.transfer_from(player, get_contract_address(), jackpot_amount);
            self.jackpot.write(self.jackpot.read() + jackpot_amount);
        }

        fn get_entry_fee(ref self: ComponentState<TState>, jackpot: u256) -> u256 {
            12
        }

        fn new_combat(
            ref self: ComponentState<TState>,
            attempt_id: u64,
            attempt_node: AttemptNodePath,
            attempt_info: AttemptInfo,
        ) {}
    }
}
