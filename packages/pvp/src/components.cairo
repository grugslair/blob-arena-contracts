use ba_combat::{Action, CombatantState, Player};
use ba_loadout::Attributes;
use core::metaprogramming::TypeEqual;
use starknet::storage::{Mutable, PendingStoragePath, StoragePath, StoragePointerReadAccess};
use starknet::{ContractAddress, get_caller_address};

pub type PvpNodePath = StoragePath<Mutable<PvpNode>>;

#[derive(Copy, Drop, Serde, PartialEq, Introspect, Default, starknet::Store)]
pub enum LobbyPhase {
    #[default]
    InActive,
    Invited,
    Responded,
    Accepted,
}

#[derive(Copy, Drop, Serde, PartialEq, Introspect, Default, starknet::Store)]
pub enum CombatPhase {
    #[default]
    None,
    Created,
    Commit,
    Player1Committed,
    Player2Committed,
    Player1Revealed,
    Player2Revealed,
    WinnerPlayer1,
    WinnerPlayer2,
}


#[starknet::storage_node]
pub struct LobbyNode {
    pub phase: LobbyPhase,
    pub loadout_address: ContractAddress,
    pub attributes_1: Attributes,
    pub combatant_2: (Attributes, [felt252; 4]),
}


#[starknet::storage_node]
pub struct PvpNode {
    pub time_limit: u64,
    pub player_1: ContractAddress,
    pub player_2: ContractAddress,
    pub commit: felt252,
    pub reveal: (Action, felt252),
    pub player_states: [CombatantState; 2],
    pub orb_1: felt252,
    pub orb_2: felt252,
    pub phase: CombatPhase,
    pub round: u32,
    pub timestamp: u64,
}


#[derive(Drop)]
pub enum AddressOrPtr<P> {
    Address: ContractAddress,
    Ptr: P,
}


pub trait AddressOrPtrTrait<P> {
    fn read(ref self: AddressOrPtr<P>) -> ContractAddress;
    fn final_read(self: @AddressOrPtr<P>) -> ContractAddress;
}

impl AddressOrPtrImpl<
    P,
    +Drop<P>,
    +StoragePointerReadAccess<P>,
    +TypeEqual<ContractAddress, StoragePointerReadAccess::<P>::Value>,
> of AddressOrPtrTrait<P> {
    fn read(ref self: AddressOrPtr<P>) -> ContractAddress {
        match @self {
            AddressOrPtr::Address(addr) => *addr,
            AddressOrPtr::Ptr(ptr) => {
                let address = ptr.read();
                self = AddressOrPtr::Address(address);
                address
            },
        }
    }

    fn final_read(self: @AddressOrPtr<P>) -> ContractAddress {
        match self {
            AddressOrPtr::Address(addr) => *addr,
            AddressOrPtr::Ptr(ptr) => { ptr.read() },
        }
    }
}

#[derive(Drop)]
pub struct MaybePlayers<P> {
    pub player1: AddressOrPtr<P>,
    pub player2: AddressOrPtr<P>,
}


#[generate_trait]
impl MaybePlayersImpl<P> of MaybePlayersTrait<P> {
    fn new(player1: AddressOrPtr<P>, player2: AddressOrPtr<P>) -> MaybePlayers<P> {
        MaybePlayers { player1, player2 }
    }
}

#[generate_trait]
pub impl PvpNodeImpl of PvpNodeTrait {
    fn assert_caller_is_player(self: @PvpNodePath, player: Player) -> ContractAddress {
        let caller = get_caller_address();
        assert(
            caller == match player {
                Player::Player1 => self.player_1.read(),
                Player::Player2 => self.player_2.read(),
            },
            'Caller not player',
        );
        caller
    }

    fn assert_caller_is_player_return_maybe(
        self: @PvpNodePath, player: Player,
    ) -> MaybePlayers<PendingStoragePath<Mutable<ContractAddress>>> {
        let caller = get_caller_address();
        match player {
            Player::Player1 => {
                assert(caller == self.player_1.read(), 'Caller not player 1');
                MaybePlayersTrait::new(
                    AddressOrPtr::Ptr(self.player_1), AddressOrPtr::Address(caller),
                )
            },
            Player::Player2 => {
                assert(caller == self.player_2.read(), 'Caller not player 2');
                MaybePlayersTrait::new(
                    AddressOrPtr::Address(caller), AddressOrPtr::Ptr(self.player_2),
                )
            },
        }
    }
}

