module chain_reaction_fun::chain_reaction_game {
    use std::signer;
    use std::vector;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use chain_reaction_fun::admin_contract;
    use chain_reaction_fun::game_verifier;
    use chain_reaction_fun::game_room_manager;

    struct GameState has key {
        rooms: vector<u64>,
        active_games: u64,
        total_fees: u64,
        fee_percentage: u8,
    }

    const E_NOT_INITIALIZED: u64 = 1;
    const E_ALREADY_INITIALIZED: u64 = 2;
    const E_NOT_ADMIN: u64 = 3;
    const E_INVALID_WINNER: u64 = 4;
    const E_NOT_CONTRACT_ACCOUNT: u64 = 5;

    public fun initialize(account: &signer) {
        assert!(!exists<GameState>(signer::address_of(account)), E_ALREADY_INITIALIZED);
        move_to(account, GameState {
            rooms: vector::empty(),
            active_games: 0,
            total_fees: 0,
            fee_percentage: 5, // 5% fee
        });
        admin_contract::initialize(account);
        game_room_manager::initialize(account);
    }

    public entry fun create_room(creator: &signer, bet_amount: u64, max_players: u8) acquires GameState {
        assert!(exists<GameState>(@chain_reaction_fun), E_NOT_INITIALIZED);
        let room_id = game_room_manager::create_room(creator, bet_amount, max_players);
        let state = borrow_global_mut<GameState>(@chain_reaction_fun);
        vector::push_back(&mut state.rooms, room_id);
    }

    public entry fun join_room(player: &signer, room_id: u64) acquires GameState {
        assert!(exists<GameState>(@chain_reaction_fun), E_NOT_INITIALIZED);
        game_room_manager::join_room(player, room_id);
        let state = borrow_global_mut<GameState>(@chain_reaction_fun);
        if (game_room_manager::is_room_full(room_id)) {
            state.active_games = state.active_games + 1;
        }
    }

    public entry fun leave_room(player: &signer, room_id: u64) acquires GameState {
        assert!(exists<GameState>(@chain_reaction_fun), E_NOT_INITIALIZED);
        let (refunded, penalty) = game_room_manager::leave_room(player, room_id);
        if (!refunded) {
            let state = borrow_global_mut<GameState>(@chain_reaction_fun);
            state.total_fees = state.total_fees + penalty;
        }
    }

    public entry fun declare_winner(room_id: u64, winner_address: address, game_state: vector<u8>, signature: vector<u8>) acquires GameState {
        assert!(exists<GameState>(@chain_reaction_fun), E_NOT_INITIALIZED);
        assert!(game_verifier::verify_winner(room_id, winner_address, game_state, signature), E_INVALID_WINNER);

        let state = borrow_global_mut<GameState>(@chain_reaction_fun);

        let fee_amount = game_room_manager::distribute_winnings_with_fee(room_id, winner_address, state.fee_percentage);

        state.total_fees = state.total_fees + fee_amount;
        state.active_games = state.active_games - 1;

        let index = 0;
        let len = vector::length(&state.rooms);
        while (index < len) {
            if (*vector::borrow(&state.rooms, index) == room_id) {
                vector::remove(&mut state.rooms, index);
                break
            };
            index = index + 1;
        };

        game_room_manager::close_room(room_id);
    }

    public entry fun withdraw_fees(admin: &signer, account:address) acquires GameState {
        assert!(admin_contract::is_admin(admin), E_NOT_ADMIN);
        assert!(signer::address_of(admin) == @chain_reaction_fun, E_NOT_CONTRACT_ACCOUNT);

        let state = borrow_global_mut<GameState>(@chain_reaction_fun);
        let fee_amount = state.total_fees;
        state.total_fees = 0;
        // Asumiendo que las tarifas se acumulan en la cuenta del contrato
        coin::transfer<AptosCoin>(admin,  account, fee_amount);
    }
}