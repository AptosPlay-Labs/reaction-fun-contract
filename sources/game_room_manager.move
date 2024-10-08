module chain_reaction_fun::game_room_manager {
    use std::signer;
    use std::vector;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::timestamp;
    use aptos_std::table::{Self, Table};
    use chain_reaction_fun::admin_contract;
    use chain_reaction_fun::game_verifier;

    struct Room has store {
        id: u64,
        creator: address,
        bet_amount: u64,
        max_players: u8,
        current_players: vector<address>,
        vault: Coin<AptosCoin>,
        state: u8, // 0: Waiting, 1: Started, 2: Finished, 3: Abandoned
        created_at: u64,
    }

    struct GameRooms has key {
        rooms: Table<u64, Room>,
        room_counter: u64,
    }

    const E_ROOM_NOT_FOUND: u64 = 1;
    const E_ROOM_FULL: u64 = 2;
    const E_ALREADY_JOINED: u64 = 3;
    const E_NOT_IN_ROOM: u64 = 4;
    const E_ROOM_STARTED: u64 = 5;
    const E_ROOM_MIN_PLAYERS: u64 = 6;
    const E_ROOM_MIN_BET: u64 = 7;
    const E_INSUFFICIENT_BALANCE: u64 = 8;
    const E_ALREADY_INITIALIZED: u64 = 9;
    const E_UNAUTHORIZED: u64 = 10;
    const E_INVALID_SIGNATURE: u64 = 11;
    const E_INVALID_WINNER: u64 = 12;
    const E_NOT_INITIALIZED: u64 = 13;
    const E_INVALID_CALLER_WIN: u64 = 14;

    //public fun initialize(account: &signer) {
    fun init_module(account: &signer) {
        assert!(!exists<GameRooms>(signer::address_of(account)), E_ALREADY_INITIALIZED);
        move_to(account, GameRooms {
            rooms: table::new(),
            room_counter: 0,
        });
    }

    // public fun initialize(account: &signer) {
    //     assert!(!exists<GameRooms>(signer::address_of(account)), E_ALREADY_INITIALIZED);
    //     move_to(account, GameRooms {
    //         rooms: table::new(),
    //         room_counter: 0,
    //     });
    // }

    public fun create_room(creator: &signer, bet_amount: u64, max_players: u8): u64 acquires GameRooms {
        assert!(max_players > 1, E_ROOM_MIN_PLAYERS);
        assert!(bet_amount > 0, E_ROOM_MIN_BET);
        let game_rooms = borrow_global_mut<GameRooms>(@chain_reaction_fun);
        let room_id = game_rooms.room_counter + 1;
        game_rooms.room_counter = game_rooms.room_counter + 1;

        let creator_address = signer::address_of(creator);
        let room = Room {
            id: room_id,
            creator: creator_address,
            bet_amount,
            max_players,
            current_players: vector::empty(),
            vault: coin::zero<AptosCoin>(),
            state: 0, // Waiting
            created_at: timestamp::now_seconds(),
        };

        table::add(&mut game_rooms.rooms, room_id, room);
        let bet_amount = join_room(game_rooms, creator_address, room_id);
        place_bet(game_rooms, creator, bet_amount, room_id);

        room_id
    }

    public fun join_room(game_rooms: &mut GameRooms, player_address: address, room_id: u64): u64 {
        assert!(table::contains(&game_rooms.rooms, room_id), E_ROOM_NOT_FOUND);

        let room = table::borrow_mut(&mut game_rooms.rooms, room_id);
        assert!(room.state == 0, E_ROOM_STARTED);
        assert!(vector::length(&room.current_players) < (room.max_players as u64), E_ROOM_FULL);
        assert!(!vector::contains(&room.current_players, &player_address), E_ALREADY_JOINED);

        vector::push_back(&mut room.current_players, player_address);

        if (vector::length(&room.current_players) == (room.max_players as u64)) {
            room.state = 1; // Started
        };

        room.bet_amount
    }

    public fun place_bet(game_rooms: &mut GameRooms, player: &signer, amount: u64, room_id: u64) {
        let player_address = signer::address_of(player);
        assert!(coin::balance<AptosCoin>(player_address) >= amount, E_INSUFFICIENT_BALANCE);

        assert!(table::contains(&game_rooms.rooms, room_id), E_ROOM_NOT_FOUND);
        let room = table::borrow_mut(&mut game_rooms.rooms, room_id);
        let bet_coins = coin::withdraw<AptosCoin>(player, amount);
        coin::merge(&mut room.vault, bet_coins);
    }

    public fun join_and_bet(player: &signer, room_id: u64) acquires GameRooms {
        let game_rooms = borrow_global_mut<GameRooms>(@chain_reaction_fun);
        let player_address = signer::address_of(player);

        let bet_amount = join_room(game_rooms, player_address, room_id);
        place_bet(game_rooms, player, bet_amount, room_id);
    }

    public fun leave_room(player: &signer, room_id: u64): (bool, u64) acquires GameRooms {
        let game_rooms = borrow_global_mut<GameRooms>(@chain_reaction_fun);
        assert!(table::contains(&game_rooms.rooms, room_id), E_ROOM_NOT_FOUND);
        let room = table::borrow_mut(&mut game_rooms.rooms, room_id);

        let player_address = signer::address_of(player);
        assert!(vector::contains(&room.current_players, &player_address), E_NOT_IN_ROOM);

        // let index = 0;
        // let len = vector::length(&room.current_players);
        // while (index < len) {
        //     if (*vector::borrow(&room.current_players, index) == player_address) {
        //         vector::remove(&mut room.current_players, index);
        //         break
        //     };
        //     index = index + 1;
        // };

        if (room.state == 0) { // Waiting
            refund_bet(player_address, room.bet_amount, &mut room.vault);
            //room.max_players = room.max_players - 1;
            //room.state = 2;
            (true, 0)
        } else { // Started
            (false, room.bet_amount)
        }
    }

    public fun is_room_full(room_id: u64): bool acquires GameRooms {
        let game_rooms = borrow_global<GameRooms>(@chain_reaction_fun);
        assert!(table::contains(&game_rooms.rooms, room_id), E_ROOM_NOT_FOUND);
        let room = table::borrow(&game_rooms.rooms, room_id);
        vector::length(&room.current_players) == (room.max_players as u64)
    }

    public fun close_room(room_id: u64) acquires GameRooms {
        let game_rooms = borrow_global_mut<GameRooms>(@chain_reaction_fun);
        assert!(table::contains(&game_rooms.rooms, room_id), E_ROOM_NOT_FOUND);
        let room = table::borrow_mut(&mut game_rooms.rooms, room_id);
        room.state = 2;
    }

    fun refund_bet(player_address: address, amount: u64, vault: &mut Coin<AptosCoin>) {
        let refund = coin::extract(vault, amount);
        coin::deposit(player_address, refund);
    }


    public fun declare_winner_distribute_winnings( caller: &signer, room_id: u64,
                                                   winner_address: address,
                                                   game_state: vector<u8>,
                                                   signature: vector<u8>,
                                                   fee_percentage:u8): u64 acquires GameRooms {

        let caller_address = signer::address_of(caller);
        let game_rooms = borrow_global_mut<GameRooms>(@chain_reaction_fun);
        assert!(table::contains(&game_rooms.rooms, room_id), E_ROOM_NOT_FOUND);
        let room = table::borrow_mut(&mut game_rooms.rooms, room_id);

        assert!(caller_address == winner_address, E_INVALID_CALLER_WIN);
        assert!(vector::contains(&room.current_players, &caller_address), E_UNAUTHORIZED);
        assert!(vector::contains(&room.current_players, &winner_address), E_INVALID_WINNER);

        assert!(game_verifier::verify_winner(room_id, winner_address, game_state, signature), E_INVALID_SIGNATURE);

        let fee_amount = distribute_winnings_with_fee(room, winner_address, fee_percentage);

        fee_amount
    }

    fun distribute_winnings_with_fee(room: &mut Room, winner_address: address, fee_percentage: u8): u64 {

        let total_pot = coin::value(&room.vault);
        let fee_amount = (total_pot * (fee_percentage as u64)) / 100;
        let winnings = total_pot - fee_amount;

        let winner_coins = coin::extract(&mut room.vault, winnings);
        coin::deposit(winner_address, winner_coins);

        let fee_coins = coin::extract(&mut room.vault, fee_amount);
        let fee_account = admin_contract::get_fee_account_address();
        coin::deposit(fee_account, fee_coins);

        fee_amount
    }
}