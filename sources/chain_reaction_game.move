module chain_reaction_fun::chain_reaction_game {
    use std::signer;
    use aptos_framework::event;

    struct GameState has key {
        room_manager: address,
        bet_manager: address,
        winner_verifier: address,
        fee_manager: address,
        admin: address,
    }

    #[event]
    struct GameInitialized has drop, store {
        admin: address,
        room_manager: address,
        bet_manager: address,
        winner_verifier: address,
        fee_manager: address,
    }

    const ENO_PERMISSION: u64 = 1;

    public fun initialize(account: &signer) {
        let sender = signer::address_of(account);
        assert!(sender == @admin_address, ENO_PERMISSION);

        move_to(account, GameState {
            room_manager: @0x0,
            bet_manager: @0x0,
            winner_verifier: @0x0,
            fee_manager: @0x0,
            admin: sender,
        });

        event::emit(GameInitialized {
            admin: sender,
            room_manager: @0x0,
            bet_manager: @0x0,
            winner_verifier: @0x0,
            fee_manager: @0x0,
        });
    }

    public fun set_room_manager(account: &signer, room_manager: address) acquires GameState {
        let sender = signer::address_of(account);
        let game_state = borrow_global_mut<GameState>(@admin_address);
        assert!(sender == game_state.admin, ENO_PERMISSION);
        game_state.room_manager = room_manager;
    }

    public fun set_bet_manager(account: &signer, bet_manager: address) acquires GameState {
        let sender = signer::address_of(account);
        let game_state = borrow_global_mut<GameState>(@admin_address);
        assert!(sender == game_state.admin, ENO_PERMISSION);
        game_state.bet_manager = bet_manager;
    }

    public fun set_winner_verifier(account: &signer, winner_verifier: address) acquires GameState {
        let sender = signer::address_of(account);
        let game_state = borrow_global_mut<GameState>(@admin_address);
        assert!(sender == game_state.admin, ENO_PERMISSION);
        game_state.winner_verifier = winner_verifier;
    }

    public fun set_fee_manager(account: &signer, fee_manager: address) acquires GameState {
        let sender = signer::address_of(account);
        let game_state = borrow_global_mut<GameState>(@admin_address);
        assert!(sender == game_state.admin, ENO_PERMISSION);
        game_state.fee_manager = fee_manager;
    }

    #[view]
    public fun get_game_state(): (address, address, address, address, address) acquires GameState {
        let game_state = borrow_global<GameState>(@admin_address);
        (
            game_state.room_manager,
            game_state.bet_manager,
            game_state.winner_verifier,
            game_state.fee_manager,
            game_state.admin
        )
    }

    #[test(admin = @admin_address)]
    public entry fun test_initialize_and_setters(admin: signer) acquires GameState {
        initialize(&admin);
        
        let (room_manager, bet_manager, winner_verifier, fee_manager, admin_addr) = get_game_state();
        assert!(room_manager == @0x0, 0);
        assert!(bet_manager == @0x0, 1);
        assert!(winner_verifier == @0x0, 2);
        assert!(fee_manager == @0x0, 3);
        assert!(admin_addr == signer::address_of(&admin), 4);

        set_room_manager(&admin, @0x1);
        set_bet_manager(&admin, @0x2);
        set_winner_verifier(&admin, @0x3);
        set_fee_manager(&admin, @0x4);

        let (room_manager, bet_manager, winner_verifier, fee_manager, _) = get_game_state();
        assert!(room_manager == @0x1, 5);
        assert!(bet_manager == @0x2, 6);
        assert!(winner_verifier == @0x3, 7);
        assert!(fee_manager == @0x4, 8);
    }
}