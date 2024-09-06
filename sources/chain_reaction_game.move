module chain_reaction_fun::chain_reaction_game {
    use std::signer;
    use aptos_std::table::{Self, Table};
    use chain_reaction_fun::admin_contract;
    use chain_reaction_fun::game_room_manager;

    struct GameState has key {
        rooms: Table<u64, bool>,
        created_games:u64,
        active_games: u64,
        end_games: u64,
        total_fees: u64,
        fee_percentage: u8,
    }

    // Error constants
    const E_NOT_INITIALIZED: u64 = 1;
    const E_ALREADY_INITIALIZED: u64 = 2;
    const E_NOT_ADMIN: u64 = 3;
    const E_INVALID_WINNER: u64 = 4;
    const E_NOT_CONTRACT_ACCOUNT: u64 = 5;
    const E_ROOM_NOT_FOUND: u64 = 6;
    const E_NOT_REFOUND: u64 = 7;
    const E_INVALID_FEE_PERCENTAGE: u64 = 8; // New error constant

    fun init_module(account: &signer) {
        assert!(!exists<GameState>(signer::address_of(account)), E_ALREADY_INITIALIZED);
        move_to(account, GameState {
            rooms: table::new(),
            created_games: 0,
            active_games: 0,
            end_games: 0,
            total_fees: 0,
            fee_percentage: 5, // 5% fee
        });
        //admin_contract::initialize(account);
        //game_room_manager::initialize(account);
    }

    public entry fun create_room(creator: &signer, bet_amount: u64, max_players: u8) acquires GameState {
        assert!(exists<GameState>(@chain_reaction_fun), E_NOT_INITIALIZED);
        let room_id = game_room_manager::create_room(creator, bet_amount, max_players);
        let state = borrow_global_mut<GameState>(@chain_reaction_fun);
        table::add(&mut state.rooms, room_id, true);
        state.created_games = state.created_games + 1;
        state.active_games = state.active_games + 1; // Incrementar active_games al crear una sala
    }

    public entry fun join_room(player: &signer, room_id: u64) {
        assert!(exists<GameState>(@chain_reaction_fun), E_NOT_INITIALIZED);
        game_room_manager::join_and_bet(player, room_id);
    }

    public entry fun leave_room(player: &signer, room_id: u64) acquires GameState {
        assert!(exists<GameState>(@chain_reaction_fun), E_NOT_INITIALIZED);
        let state = borrow_global_mut<GameState>(@chain_reaction_fun);
        assert!(table::contains(&state.rooms, room_id), E_ROOM_NOT_FOUND);
        let (refunded, bet_amount) = game_room_manager::leave_room(player, room_id);

        assert!(refunded==true, E_NOT_REFOUND);
        assert!(bet_amount==0, E_NOT_REFOUND);
        state.end_games = state.end_games + 1;
        table::upsert(&mut state.rooms, room_id, false);
        game_room_manager::close_room(room_id);

        // if (!refunded) {
        //     //aqui deberia declararce winer al otro jugador ya que uno avandono el juego
        //     //state.total_fees = state.total_fees + penalty;
        // } else {
        //     assert!(table::contains(&state.rooms, room_id), E_ROOM_NOT_FOUND);
        //     state.active_games = state.active_games - 1;
        //     state.end_games = state.end_games + 1;
        //     table::upsert(&mut state.rooms, room_id, false);
        //     game_room_manager::close_room(room_id);
        // }
    }

    public entry fun declare_winner(caller: &signer, room_id: u64, winner_address: address, game_state: vector<u8>, signature: vector<u8>) acquires GameState {
        assert!(exists<GameState>(@chain_reaction_fun), E_NOT_INITIALIZED);
        //assert!(game_verifier::verify_winner(room_id, winner_address, game_state, signature), E_INVALID_WINNER);

        let state = borrow_global_mut<GameState>(@chain_reaction_fun);
        assert!(table::contains(&state.rooms, room_id), E_ROOM_NOT_FOUND);

        let fee_amount = game_room_manager::declare_winner_distribute_winnings(caller, room_id, winner_address, game_state, signature, state.fee_percentage);

        state.total_fees = state.total_fees + fee_amount;
        state.active_games = state.active_games - 1;
        state.end_games = state.end_games + 1;
        table::upsert(&mut state.rooms, room_id, false);

        game_room_manager::close_room(room_id);
    }

    // public entry fun withdraw_fees(admin: &signer, account: address) acquires GameState {
    //     assert!(admin_contract::is_admin(signer::address_of(admin)), E_NOT_ADMIN);
    //     assert!(signer::address_of(admin) == @chain_reaction_fun, E_NOT_CONTRACT_ACCOUNT);
    //
    //     let state = borrow_global_mut<GameState>(@chain_reaction_fun);
    //     let fee_amount = state.total_fees;
    //     state.total_fees = 0;
    //     coin::transfer<AptosCoin>(admin, account, fee_amount);
    // }

    public entry fun change_fee_percentage(admin: &signer, new_percentage: u8) acquires GameState {
        assert!(admin_contract::is_admin(admin), E_NOT_ADMIN);
        assert!(new_percentage <= 100, E_INVALID_FEE_PERCENTAGE);

        let state = borrow_global_mut<GameState>(@chain_reaction_fun);
        state.fee_percentage = new_percentage;
    }

    #[view]
    public fun get_game_stats(): (u64, u64, u64, u64, u8) acquires GameState {
        assert!(exists<GameState>(@chain_reaction_fun), E_NOT_INITIALIZED);
        let state = borrow_global<GameState>(@chain_reaction_fun);
        (
            state.created_games,
            state.active_games,
            state.end_games,
            state.total_fees,
            state.fee_percentage
        )
    }


}