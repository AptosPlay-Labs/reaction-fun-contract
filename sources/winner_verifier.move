module chain_reaction_fun::winner_verifier {
    use std::signer;
    use std::vector;
    use aptos_framework::event;

    struct GameResult has key {
        room_id: u64,
        winner: address,
        signature: vector<u8>,
    }

    #[event]
    struct ResultSubmitted has drop, store {
        room_id: u64,
        winner: address,
    }

    #[event]
    struct GameStarted has drop, store {
        room_id: u64,
        players: vector<address>,
    }

    const ENOT_ADMIN: u64 = 1;
    const EGAME_NOT_STARTED: u64 = 2;
    const EINVALID_SIGNATURE: u64 = 3;

    struct GameState has key {
        active_games: vector<u64>,
    }

    public fun initialize(account: &signer) {
        assert!(signer::address_of(account) == @admin_address, ENOT_ADMIN);
        move_to(account, GameState { active_games: vector::empty() });
    }

    public fun start_game(admin: &signer, room_id: u64, players: vector<address>) acquires GameState {
        assert!(signer::address_of(admin) == @admin_address, ENOT_ADMIN);
        let game_state = borrow_global_mut<GameState>(@admin_address);
        vector::push_back(&mut game_state.active_games, room_id);

        event::emit(GameStarted {
            room_id,
            players,
        });
    }

    public fun submit_result(account: &signer, room_id: u64, winner: address, signature: vector<u8>) acquires GameState {
        let sender = signer::address_of(account);
        assert!(sender == @admin_address, ENOT_ADMIN);

        let game_state = borrow_global_mut<GameState>(@admin_address);
        assert!(vector::contains(&game_state.active_games, &room_id), EGAME_NOT_STARTED);

        // Aqui iria la logica de verificacion de la firma
        // Por simplicidad, asumimos que la firma es valida si no esta vacia
        assert!(!vector::is_empty(&signature), EINVALID_SIGNATURE);

        move_to(account, GameResult {
            room_id,
            winner,
            signature,
        });

        // Eliminar el juego de la lista de juegos activos
        let (_, index) = vector::index_of(&game_state.active_games, &room_id);
        vector::remove(&mut game_state.active_games, index);

        event::emit(ResultSubmitted {
            room_id,
            winner,
        });
    }

    public fun verify_result(room_id: u64, winner: address, signature: vector<u8>): bool acquires GameResult {
        let game_result = borrow_global<GameResult>(@admin_address);

        game_result.room_id == room_id &&
        game_result.winner == winner &&
        game_result.signature == signature
    }

    #[view]
    public fun get_result(): (u64, address, vector<u8>) acquires GameResult {
        let game_result = borrow_global<GameResult>(@admin_address);
        (game_result.room_id, game_result.winner, *&game_result.signature)
    }

    #[view]
    public fun is_game_active(room_id: u64): bool acquires GameState {
        let game_state = borrow_global<GameState>(@admin_address);
        vector::contains(&game_state.active_games, &room_id)
    }

    #[test(admin = @admin_address)]
    public entry fun test_winner_verification(admin: signer) acquires GameState, GameResult {
        initialize(&admin);

        let room_id = 0;
        let winner = @0x1;
        let players = vector::singleton(winner);
        let signature = b"test_signature";

        start_game(&admin, room_id, players);
        assert!(is_game_active(room_id), 0);

        submit_result(&admin, room_id, winner, signature);
        assert!(!is_game_active(room_id), 1);

        let (result_room_id, result_winner, result_signature) = get_result();
        assert!(result_room_id == room_id, 2);
        assert!(result_winner == winner, 3);
        assert!(result_signature == signature, 4);

        assert!(verify_result(room_id, winner, signature), 5);
    }
}