use starknet::{ContractAddress, get_caller_address, get_block_number};


#[derive(Copy, Drop, Serde)]
struct PvPChallenge {
    id: felt252,
    sender: ContractAddress,
    receiver: ContractAddress,
    sender_combatant: felt252,
    receiver_combatant: felt252,
    phase_time: u64,
    invite_open: bool,
    response_open: bool,
    collection_address: ContractAddress,
}

#[dojo::model]
#[derive(Drop, Serde, Copy)]
struct PvPCombatants {
    #[key]
    id: felt252,
    combatants: (felt252, felt252),
}


#[dojo::model]
#[derive(Copy, Drop, Serde)]
struct PvPChallengeScore {
    #[key]
    player: ContractAddress,
    #[key]
    collection_address: ContractAddress,
    #[key]
    token_high: u128,
    #[key]
    token_low: u128,
    wins: u64,
    losses: u64,
    max_consecutive_wins: u64,
    current_consecutive_wins: u64,
}

#[dojo::model]
#[derive(Copy, Drop, Serde)]
struct PvPChallengeInvite {
    #[key]
    id: felt252,
    sender: ContractAddress,
    receiver: ContractAddress,
    collection_address: ContractAddress,
    combatant: felt252,
    phase_time: u64,
    open: bool,
}

#[dojo::model]
#[derive(Copy, Drop, Serde)]
struct PvPChallengeResponse {
    #[key]
    id: felt252,
    combatant: felt252,
    open: bool,
}

fn make_pvp_challenge(
    invite: @PvPChallengeInvite, response: @PvPChallengeResponse
) -> PvPChallenge {
    PvPChallenge {
        id: *invite.id,
        sender: *invite.sender,
        receiver: *invite.receiver,
        sender_combatant: *invite.combatant,
        receiver_combatant: *response.combatant,
        phase_time: *invite.phase_time,
        invite_open: *invite.open,
        response_open: *response.open,
        collection_address: *invite.collection_address,
    }
}

#[generate_trait]
impl PvPChallengeImpl of PvPChallengeTrait {
    fn assert_caller_sender(self: @PvPChallenge) -> ContractAddress {
        let caller = get_caller_address();
        assert(*self.sender == caller, 'Not the sender');
        caller
    }

    fn assert_caller_receiver(self: @PvPChallenge) -> ContractAddress {
        let caller = get_caller_address();
        assert(*self.receiver == caller, 'Not the receiver');
        caller
    }

    fn invite(self: @PvPChallenge) -> PvPChallengeInvite {
        PvPChallengeInvite {
            id: *self.id,
            sender: *self.sender,
            receiver: *self.receiver,
            combatant: *self.sender_combatant,
            phase_time: *self.phase_time,
            open: *self.invite_open,
            collection_address: *self.collection_address,
        }
    }
    fn response(self: @PvPChallenge) -> PvPChallengeResponse {
        PvPChallengeResponse {
            id: *self.id, combatant: *self.receiver_combatant, open: *self.response_open,
        }
    }
}

#[generate_trait]
impl PvPChallengeScoreImpl of PvPChallengeScoreTrait {
    fn win(ref self: PvPChallengeScore) {
        self.current_consecutive_wins += 1;
        self.wins += 1;
        if self.current_consecutive_wins > self.max_consecutive_wins {
            self.max_consecutive_wins = self.current_consecutive_wins;
        }
    }
    fn lose(ref self: PvPChallengeScore) {
        self.current_consecutive_wins = 0;
        self.losses += 1;
    }
}
