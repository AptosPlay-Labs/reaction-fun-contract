module chain_reaction_fun::bet_manager {
    use std::signer;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::event;
    
    struct BetInfo has key {
        total_bet: u64,
        winner: address,
    }

    #[event]
    struct WinnerDeclared has drop, store {
        room_id: u64,
        winner: address,
        prize: u64,
    }

    const ENOT_WINNER: u64 = 1;

    public fun initialize_bet(room_id: u64, total_bet: u64) {
        move_to(@admin_address, BetInfo {
            total_bet,
            winner: @0x0,
        });
    }

    public fun set_winner(account: &signer, room_id: u64, winner: address) acquires BetInfo {
        let sender = signer::address_of(account);
        assert!(sender == @admin_address, 0);

        let bet_info = borrow_global_mut<BetInfo>(@admin_address);
        bet_info.winner = winner;
    }

    public fun claim_prize(account: &signer, room_id: u64) acquires BetInfo {
        let sender = signer::address_of(account);
        let bet_info = borrow_global<BetInfo>(@admin_address);

        assert!(sender == bet_info.winner, ENOT_WINNER);

        let fee = bet_info.total_bet / 20; // 5% de fee
        let prize = bet_info.total_bet - fee;

        coin::transfer<AptosCoin>(@admin_address, sender, prize);

        event::emit(WinnerDeclared {
            room_id,
            winner: sender,
            prize,
        });
    }

    #[view]
    public fun get_bet_info(): (u64, address) acquires BetInfo {
        let bet_info = borrow_global<BetInfo>(@admin_address);
        (bet_info.total_bet, bet_info.winner)
    }

    #[test(admin = @admin_address, winner = @0x1)]
    public entry fun test_bet_flow(admin: signer, winner: signer) acquires BetInfo {
        initialize_bet(0, 1000);
        
        let (total_bet, current_winner) = get_bet_info();
        assert!(total_bet == 1000, 0);
        assert!(current_winner == @0x0, 1);

        set_winner(&admin, 0, signer::address_of(&winner));
        
        let (_, current_winner) = get_bet_info();
        assert!(current_winner == signer::address_of(&winner), 2);

        claim_prize(&winner, 0);
    }
}